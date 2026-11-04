"""Original loopable electrical room tone. No sampled or third-party audio."""
from pathlib import Path
import math,wave,struct
out=Path(__file__).resolve().parents[2]/'assets/audio';out.mkdir(parents=True,exist_ok=True)
rate=24000
with wave.open(str(out/'refrigeration.wav'),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate)
 for i in range(rate*6):
  t=i/rate
  s=.05*math.sin(2*math.pi*60*t)+.018*math.sin(2*math.pi*120*t)+.008*math.sin(2*math.pi*240*t)
  s*=.85+.15*math.sin(2*math.pi*t/3)
  w.writeframesraw(struct.pack('<h',int(s*32767)))
