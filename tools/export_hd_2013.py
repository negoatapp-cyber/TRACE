"""Applique la finition HD à la version Web filmée, en conservant ses ressources compilées."""
import argparse
import hashlib
import struct
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1]
ORIGINAL_SHA256 = "4b7d0a488bb5043d9813a68eef962fa006c170c11a873ef6892b5d8aa5bb54ab"
FILES = (
    "scripts/finition_hd.gd", "assets/decor/matieres/enduit_chaud_hd.webp",
    "shaders/goudron.gdshader", "shaders/facade.gdshader", "shaders/bd_sol.gdshader",
    "shaders/bd_lumiere.gdshaderinc", "shaders/bd_encrage_web.gdshader",
)

def pad(data, stride):
    return data + bytes(-len(data) % stride)

def read_directory(pack, base, directory):
    count, = struct.unpack_from("<I", pack, directory)
    pos = directory + 4
    entries = {}
    for _ in range(count):
        length, = struct.unpack_from("<I", pack, pos)
        name = pack[pos+4:pos+4+length].rstrip(b"\0").decode()
        pos += 4 + length
        offset, size, digest, flags = struct.unpack_from("<QQ16sI", pack, pos)
        entries[name] = (offset, size, digest, flags)
        pos += 36
    return entries

def autoload(config):
    key = b"autoload/FinitionHD"
    path = b"*res://scripts/finition_hd.gd"
    value = struct.pack("<II", 4, len(path)) + pad(path, 4)
    count, = struct.unpack_from("<I", config, 4)
    return (config[:4] + struct.pack("<I", count + 1) + config[8:] +
            struct.pack("<I", len(key)) + key + struct.pack("<I", len(value)) + value)

def build(source, target):
    original = source.read_bytes()
    if hashlib.sha256(original).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Cette version du jeu diffère de la référence testée du 21 novembre.")
    base, directory = struct.unpack_from("<QQ", original, 24)
    entries = read_directory(original, base, directory)
    pack = bytearray(original[:directory])
    def add(name, data):
        pack.extend(bytes(-len(pack) % 16))
        entries[name] = (len(pack)-base, len(data), hashlib.md5(data).digest(), 0)
        pack.extend(data)
    for file in FILES:
        add(file, (SOURCE/file).read_bytes())
    offset, size, _, _ = entries["project.binary"]
    add("project.binary", autoload(original[base+offset:base+offset+size]))
    # Conserver la version filmée du lycée, y compris ses pièces et ses matériaux privés.
    entries["scripts/lycee_source_2013.gdc"] = entries.pop("scripts/habillage_lycee.gdc")
    for alias, destination in [("lycee_source_2013", "lycee_source_2013.gdc"),
                               ("habillage_lycee", "habillage_lycee_hd.gd")]:
        add("scripts/"+alias+".gd.remap", f'[remap]\n\npath="res://scripts/{destination}"\n'.encode())
    script = (SOURCE/"scripts/habillage_lycee_hd.gd").read_text()
    add("scripts/habillage_lycee_hd.gd", script.replace('extends "res://scripts/habillage_lycee.gd"',
        'extends "res://scripts/lycee_source_2013.gd"').encode())
    pack.extend(bytes(-len(pack) % 16))
    struct.pack_into("<Q", pack, 32, len(pack))
    pack.extend(struct.pack("<I", len(entries)))
    for name, entry in sorted(entries.items()):
        name_bytes = pad(name.encode(), 4)
        pack.extend(struct.pack("<I",len(name_bytes)) + name_bytes + struct.pack("<QQ16sI",*entry))
    target.write_bytes(pack)

if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("original", type=Path)
    cli.add_argument("sortie", type=Path)
    args = cli.parse_args()
    if args.original.resolve() == args.sortie.resolve():
        cli.error("Choisir un fichier de sortie distinct.")
    build(args.original, args.sortie)
