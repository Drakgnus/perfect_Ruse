import os, pathlib, subprocess, sys
root=pathlib.Path(__file__).resolve().parents[1]
env=os.environ.copy()
env['APPDATA']=str(root/'runtime-profile')
godot=os.environ.get('GODOT_BIN','D:/Programas/Godot/Godot_v4.7-stable_win64.exe')
checks=[('character-tests',['--headless','--script','res://tests/character_integration.gd']),('wardrobe-tests',['--headless','--script','res://tests/wardrobe_integration.gd']),('game-1200',['--headless','--quit-after','1200','res://scenes/main.tscn']),('gallery',['--resolution','1600x1000','res://scenes/character_gallery.tscn','--','--capture-gallery']),('wardrobe-capture',['--resolution','1280x800','res://scenes/wardrobe.tscn','--','--capture-wardrobe']),('visual-smoke',['--resolution','1280x800','--script','res://tests/character_visual_smoke.gd'])]
checks += [('placement-tests',['--headless','--script','res://tests/placement_integration.gd']),('cars-on-road',['--headless','--script','res://tests/cars_on_road.gd']),('conversion-playable',['--headless','--script','res://tests/conversion_playable.gd']),('recovery',['--headless','--script','res://tests/recovery_check.gd']),('placement-capture',['--resolution','1280x800','--script','res://tests/urban_visual_smoke.gd']),('city-tests',['--headless','--script','res://tests/city_regression.gd']),('routes-pause',['--resolution','1280x800','--script','res://tests/routes_pause_integration.gd']),('pause-exit',['--headless','--script','res://tests/pause_exit.gd'])]
if len(sys.argv)>1:
 checks=[c for c in checks if c[0] in sys.argv[1:]]
for name,args in checks:
 p=subprocess.run([godot,'--path',str(root),'--log-file',str(root/(name+'.log'))]+args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
 text=p.stdout.decode('utf-8',errors='replace')
 (root/(name+'.stdout.log')).write_text(text,encoding='utf-8')
 errors=[line for line in text.splitlines() if ('ERROR:' in line or 'CrashHandler' in line) and 'Failed to read the root certificate store' not in line]
 ok=p.returncode==0 and not errors
 print(name,'PASS' if ok else 'FAIL', 'exit',p.returncode,flush=True)
 for line in text.splitlines():
  if any(s in line for s in ['TESTS','VISUAL_SMOKE','CARS_ON_ROAD','PAUSE_EXIT','ERROR:','Parse Error','leaked','resources still']):print(line,flush=True)
 if not ok:sys.exit(1)
