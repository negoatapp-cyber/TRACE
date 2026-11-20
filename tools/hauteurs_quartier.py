"""Associe les hauteurs BD TOPO aux seules empreintes historiques compatibles.
Usage: python tools/hauteurs_quartier.py cache/bdtopo.json data/quartier_reel.txt data/marseille/hauteurs.json
"""
import json,sys
from pathlib import Path
from shapely.geometry import Polygon, shape
from shapely.ops import transform
from pyproj import Transformer
tf=Transformer.from_crs(4326,'+proj=aeqd +lat_0=43.3268 +lon_0=5.412 +datum=WGS84',always_xy=True)
def proj(x,y,z=None):
    a,b=tf.transform(x,y)
    return a,[-n for n in b]
features=json.loads(Path(sys.argv[1]).read_text())['features']
candidats=[(transform(proj,shape(f['geometry'])),f['properties']) for f in features]
output=Path(sys.argv[3])
origines=json.loads(output.read_text()) if output.exists() else {}
results={}
for line in Path(sys.argv[2]).read_text().splitlines():
    if not line.startswith('B|'):continue
    _,nom,old,style,coord,*period=line.split('|')
    if period or nom in results: continue
    polygon=Polygon([tuple(map(float,p.split(','))) for p in coord.split()])
    if not polygon.is_valid:continue
    matches=[]
    for g,t in candidats:
        if not g.is_valid or not polygon.intersects(g):continue
        iou=polygon.intersection(g).area/polygon.union(g).area
        if iou<.80 or not t['hauteur']:continue
        date=t['date_d_apparition'] or t['date_creation'] or '9999'
        if date[:4]>'2014':continue
        matches.append((iou,t))
    matches.sort(key=lambda v:-v[0])
    if len(matches)==1:
        overlap,t=matches[0]
        results[nom]=dict(hauteur=t['hauteur'],estimation_origine=origines.get(nom,{}).get("estimation_origine",float(old)),cleabs=t['cleabs'],
            methode=t['methode_d_acquisition_altimetrique'],precision_m=t['precision_altimetrique'],
            recouvrement=round(overlap,3),date=t['date_d_apparition'] or t['date_creation'])
Path(sys.argv[3]).write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print(len(results),'correspondances',list(results)[:8])
