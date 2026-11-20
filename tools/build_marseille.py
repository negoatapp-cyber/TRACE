"""Build the offline city atlas from BBBike OSM, Datactivist boundaries and IGN RGE ALTI.
Usage: python tools/build_marseille.py <source-cache> <output-dir>
Dependencies: GDAL ogr2ogr, numpy, Pillow, shapely>=2, pyproj, mapbox-earcut.
"""
import concurrent.futures, gzip, hashlib, json, math, re, subprocess, sys, time, zlib
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen
import mapbox_earcut as earcut
import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from shapely import union_all, prepare, make_valid
from shapely.geometry import shape, Polygon, LineString
from shapely.ops import transform

cache,out = map(Path,sys.argv[1:3])
cache.mkdir(parents=True,exist_ok=True)
out.mkdir(parents=True,exist_ok=True)
pbf_url='https://download.bbbike.org/osm/bbbike/Marseille/Marseille.osm.pbf'
quart_url='https://static.data.gouv.fr/resources/quartiers-de-marseille-1/20260722-092916/quartiers-marseille.geojson'
def download(url,path):
    if path.exists(): return
    for attempt in range(3):
        try:
            with urlopen(url,timeout=60) as response: data=response.read()
            temp=path.with_suffix('.part')
            temp.write_bytes(data)
            temp.replace(path)
            return
        except OSError:
            if attempt==2: raise
            time.sleep(2)
download(pbf_url,cache/'marseille.osm.pbf')
download(quart_url,cache/'quartiers.geojson')
sources = Path(__file__).resolve().parents[1]/'data'/'sources'
# The BBBike west boundary cuts off Planier. The second OSM extract is disjoint.
planier=sources/'planier.osm'
for target,layer,where in [('bati','multipolygons','building IS NOT NULL'),('routes','lines','highway IS NOT NULL'),('sol','multipolygons','landuse IS NOT NULL OR natural IS NOT NULL OR leisure IS NOT NULL')]:
    for prefix,src in [('',cache/'marseille.osm.pbf'),('planier_',planier)]:
        path=cache/(prefix+target+'.geojsonl')
        if not path.exists() or (not prefix and not path.stat().st_size):
            path.unlink(missing_ok=True)
            subprocess.run(['ogr2ogr','-f','GeoJSONSeq',str(path),str(src),'-sql',f'SELECT * FROM {layer} WHERE {where}','-lco','RS=NO'],check=True)
        if not prefix and not path.stat().st_size: raise RuntimeError(f'Empty OSM layer: {layer}')
proj='+proj=aeqd +lat_0=43.3268 +lon_0=5.412 +datum=WGS84 +units=m'
forward=Transformer.from_crs(4326,proj,always_xy=True)
inverse=Transformer.from_crs(proj,4326,always_xy=True)
def local(lon,lat,z=None):
    x,y=forward.transform(lon,lat)
    return x,-np.asarray(y)
districts=json.loads((cache/'quartiers.geojson').read_text())['features']
city=union_all([shape(f['geometry']) for f in districts])
prepare(city)
bounds=transform(local,city).bounds
step=64
west,north=[math.floor(v/step)*step-step for v in bounds[:2]]
east,south=[math.ceil(v/step)*step+step for v in bounds[2:]]
xs=np.arange(west,east+1,step)
zs=np.arange(north,south+1,step)
xx,zz=np.meshgrid(xs,zs)
lon,lat=inverse.transform(xx,-zz)
# IGN tile samples at pixel centres, bilinear interpolation across tile seams.
span=180/2048
u=(lon+180)*256/span-.5
v=(90-lat)*256/span-.5
ix=np.floor(u).astype(int); iy=np.floor(v).astype(int)
tx0,tx1=ix.min()//256,(ix.max()+1)//256
ty0,ty1=iy.min()//256,(iy.max()+1)//256
mosaic=np.zeros(((ty1-ty0+1)*256,(tx1-tx0+1)*256),dtype='float32')
def fetch_tile(key):
    x,y=key
    url='https://data.geopf.fr/wmts?'+urlencode(dict(SERVICE='WMTS',REQUEST='GetTile',VERSION='1.0.0',LAYER='ELEVATION.ELEVATIONGRIDCOVERAGE.HIGHRES',STYLE='normal',FORMAT='image/x-bil;bits=32',TILEMATRIXSET='WGS84G_6_14',TILEMATRIX=11,TILEROW=y,TILECOL=x))
    path=cache/f'ign11_{x}_{y}.bil'
    download(url,path)
    raw=path.read_bytes()
    if len(raw)!=256*256*4: raw=zlib.decompress(raw)
    a=np.frombuffer(raw,'<f4').reshape(256,256).copy()
    if not np.isfinite(a).all(): raise ValueError('Non-finite elevation')
    a[(a < -100) | (a > 3000)]=0  # marine no-data around the city
    return x,y,a
keys=[(x,y) for x in range(tx0,tx1+1) for y in range(ty0,ty1+1)]
with concurrent.futures.ThreadPoolExecutor(4) as pool:
    for x,y,a in pool.map(fetch_tile,keys):
        mosaic[(y-ty0)*256:(y-ty0+1)*256,(x-tx0)*256:(x-tx0+1)*256]=a
fx=u-ix; fy=v-iy
i=ix-tx0*256; j=iy-ty0*256
height=(mosaic[j,i]*(1-fx)+mosaic[j,i+1]*fx)*(1-fy)+(mosaic[j+1,i]*(1-fx)+mosaic[j+1,i+1]*fx)*fy
if height.max()<500 or height.max()>900: raise ValueError(f'Unexpected Marseille elevation: {height.max()}')
np.rint(height*10).astype('<i2').tofile(out/'relief.bin')
resolution=6
w=math.ceil((east-west)/resolution); h=math.ceil((south-north)/resolution)
sea=(68,122,139); ground=(207,192,157); urban=(205,185,163); green=(147,165,128)
im=Image.new('RGB',(w,h),sea)
draw=ImageDraw.Draw(im)
mask=Image.new('L',(w,h),0)
def pixels(coords): return [((x-west)/(east-west)*(w-1),(z-north)/(south-north)*(h-1)) for x,z in coords]
def polygons(g):
    if g.geom_type=='Polygon': yield g
    elif g.geom_type in ('MultiPolygon','GeometryCollection'):
        for p in g.geoms: yield from polygons(p)
def paint(canvas,p,color,hole):
    canvas.polygon(pixels(p.exterior.coords),fill=color)
    for ring in p.interiors: canvas.polygon(pixels(ring.coords),fill=hole)
labels=[]
district_lines=[]
for f in districts:
    g=transform(local,shape(f['geometry']))
    for p in polygons(g):
        paint(draw,p,ground,sea)
        paint(ImageDraw.Draw(mask),p,255,0)
    pt=g.representative_point()
    labels.append([f['properties']['nom'],int(f['properties']['DEPCO'][-2:]),round(pt.x),round(pt.y)])
for f in districts:
    for p in polygons(transform(local,shape(f['geometry']))):
        district_lines.append([[round(x),round(z)] for x,z in p.simplify(20).exterior.coords])
district_lines=[l for l in district_lines if l]
def features(source):
    for prefix in ['', 'planier_']:
      with (cache/(prefix+source+'.geojsonl')).open() as file:
        for line in file:
            f=json.loads(line); g=shape(f['geometry'])
            if not city.intersects(g): continue
            if not city.covers(g):
                try: g=city.intersection(g)
                except Exception: g=city.intersection(make_valid(g))
            if not g.is_empty: yield f['properties'],transform(local,g)
for prop,g in features('sol'):
    kind=prop.get('landuse') or prop.get('natural') or prop.get('leisure')
    color={'water':sea,'basin':sea,'forest':green,'wood':green,'scrub':green,'grassland':green,'park':green,'grass':green,'residential':urban,'industrial':(185,176,166),'retail':urban,'cemetery':(164,176,148),'bare_rock':(220,208,179)}.get(kind)
    if color:
        for p in polygons(g): paint(draw,p,color,ground)
sectors=defaultdict(lambda:{'b':[],'r':[]})
stats=Counter()
def sector(x,z):return f'{math.floor(x/512)},{math.floor(z/512)}'
def tags(prop):return dict(re.findall(r'"([^"]+)"=>"([^"]*)"',prop.get('other_tags','')))
def number(value):
    m=re.fullmatch(r'(\d+(?:\.\d+)?)\s*(?:m)?',value or '')
    return float(m[1]) if m else 0
def getheight(prop,t):
    height=number(t.get('height'))
    if 1<=height<=300:return round(height,1),'tag'
    levels=number(t.get('building:levels'))
    if 0<levels<=80:return round(3*levels,1),'levels'
    return {'garage':3,'garages':3,'shed':3,'house':6,'detached':6,'apartments':15,'industrial':8,'residential':9}.get(prop['building'],8),'type'
for prop,g in features('bati'):
    height_m,source=getheight(prop,tags(prop))
    for p in polygons(g):
        if p.area<1:continue
        p=p.simplify(.15,preserve_topology=True)
        parts=[np.around(np.array(r.coords)[:-1],1) for r in [p.exterior,*p.interiors]]
        pts=np.concatenate(parts)
        ends=np.cumsum([len(a) for a in parts],dtype=np.uint32)
        tris=earcut.triangulate_float64(pts,ends)
        if len(tris)<3: continue
        cx,cz=p.centroid.coords[0]
        s=sector(cx,cz)
        sectors[s]['b'].append([prop.get('osm_id') or prop.get('osm_way_id'),height_m,source,pts.ravel().tolist(),ends.tolist(),tris.tolist()])
        paint(draw,p,(175,143,125),urban)
        stats['buildings']+=1;stats[source]+=1
widths={'motorway':10,'trunk':9,'primary':9,'secondary':8,'tertiary':7,'residential':6,'unclassified':6,'service':4,'living_street':4,'pedestrian':4,'footway':2,'steps':1.8,'path':1.6,'cycleway':2.4,'track':3}
for prop,g in features('routes'):
    kind=prop['highway']
    if kind not in widths and not kind.endswith('_link'):continue
    t=tags(prop)
    if t.get('tunnel','no')!='no':stats['tunnels_omitted']+=1;continue
    width=number(t.get('width'))
    if not 0.5<=width<=50:width=widths.get(kind,5)
    for line in ([g] if isinstance(g,LineString) else getattr(g,'geoms',[])):
        if not isinstance(line,LineString) or line.length<1:continue
        coords=line.simplify(.3).coords
        draw.line(pixels(coords),fill=(248,232,193) if width>=7 else (237,222,202),width=max(1,round(width/resolution)))
        # Split segments at grid boundaries. Each sector owns its road portions.
        pieces=defaultdict(list)
        for (x,z),(x2,z2) in zip(coords,list(coords)[1:]):
            cuts={0.,1.}
            for a,b in [(x,x2),(z,z2)]:
                if a!=b:
                    for n in range(math.floor(min(a,b)/512)+1,math.ceil(max(a,b)/512)):
                        cuts.add((n*512-a)/(b-a))
            ts=sorted(cuts)
            for lo,hi in zip(ts,ts[1:]):
                a=[round(x+(x2-x)*lo,1),round(z+(z2-z)*lo,1)]
                b=[round(x+(x2-x)*hi,1),round(z+(z2-z)*hi,1)]
                if a==b:continue
                s=sector((a[0]+b[0])/2,(a[1]+b[1])/2)
                if pieces[s] and pieces[s][-1][-2:]==a:pieces[s][-1].extend(b)
                else:pieces[s].append(a+b)
        for s,parts in pieces.items():
            for points in parts: sectors[s]['r'].append([prop.get('osm_id'),width,kind,points])
        stats['roads']+=1
for line in district_lines:draw.line(pixels(line),fill=(161,151,133),width=1)
im=Image.composite(im,Image.new('RGB',im.size,sea),mask)
im.quantize(64).save(out/'carte.png',optimize=True)
mask.save(out/'terre.png',optimize=True)
index={}
with (out/'secteurs.bin').open('wb') as f:
    for key,value in sorted(sectors.items()):
        raw=json.dumps(value,separators=(',',':')).encode()
        blob=gzip.compress(raw,compresslevel=6,mtime=0)
        index[key]=[f.tell(),len(blob),len(raw)]
        f.write(blob)
manifest=dict(bounds=[west,north,east,south],step=step,cols=len(xs),rows=len(zs),tile=512,labels=labels,index=index,stats=dict(stats),sha256_pbf=hashlib.sha256((cache/'marseille.osm.pbf').read_bytes()).hexdigest(),osm_extent=[5.277,43.142,5.720,43.438],projection=proj,ign_tiles=keys)
(out/'index.json').write_text(json.dumps(manifest,separators=(',',':'),ensure_ascii=False))
print(stats,len(sectors),height.min(),height.max(),flush=True)
