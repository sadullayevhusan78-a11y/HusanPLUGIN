import json, os, re, subprocess, tempfile, uuid
from pathlib import Path
from fastapi import FastAPI
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
from faster_whisper import WhisperModel

app = FastAPI(title="Husan Reels Local Engine")
MODEL = None

class EditRequest(BaseModel):
    input_path: str
    captions: bool = True
    mode: str = "smart"
    format: str = "reels"

def run(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr[-4000:])
    return p

def ffprobe(path):
    p = run(["ffprobe","-v","error","-show_entries","format=duration","-of","default=nw=1:nk=1",path])
    return float(p.stdout.strip())

def transcribe(path):
    global MODEL
    if MODEL is None:
        MODEL = WhisperModel("base", device="cpu", compute_type="int8")
    segments, _ = MODEL.transcribe(path, word_timestamps=True, vad_filter=True)
    words=[]
    for seg in segments:
        if seg.words:
            for w in seg.words:
                words.append({"word": w.word.strip(), "start": float(w.start), "end": float(w.end)})
    return words

def build_keep_ranges(words, duration, max_pause=0.85, pad=0.06):
    if not words:
        return [(0, duration)]
    ranges=[]
    start=max(0, words[0]["start"]-pad)
    prev=words[0]["end"]
    for w in words[1:]:
        gap=w["start"]-prev
        if gap>max_pause:
            ranges.append((start,min(duration,prev+pad)))
            start=max(0,w["start"]-pad)
        prev=max(prev,w["end"])
    ranges.append((start,min(duration,prev+pad)))
    return [(a,b) for a,b in ranges if b-a>0.08]

def render_cut(input_path, ranges, out):
    work=Path(out).with_suffix("")
    work=Path(str(work)+"_parts")
    work.mkdir(parents=True,exist_ok=True)
    parts=[]
    for i,(a,b) in enumerate(ranges):
        p=work/f"p{i:04d}.mp4"
        run(["ffmpeg","-y","-ss",str(a),"-to",str(b),"-i",input_path,
             "-an","-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p",str(p)])
        parts.append(p)
    lst=work/"list.txt"
    lst.write_text("\n".join("file '"+p.as_posix().replace("'","'\\''")+"'" for p in parts),encoding="utf-8")
    run(["ffmpeg","-y","-f","concat","-safe","0","-i",str(lst),"-c","copy",str(out)])
    return out

def ass_time(t):
    h=int(t//3600); m=int((t%3600)//60); s=t%60
    return f"{h}:{m:02d}:{s:05.2f}".replace(".",",")

def make_ass(words, path):
    lines=["[Script Info]","ScriptType: v4.00+","PlayResX: 1080","PlayResY: 1920",
           "[V4+ Styles]","Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding",
           "Style: Husan,Arial,76,&H00FFFFFF,&H00FFFFFF,&H00101010,&H00101010,1,0,0,0,100,100,0,0,1,3,0,2,60,60,170,1",
           "[Events]","Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text"]
    i=0
    while i<len(words):
        chunk=words[i:i+5]
        start=chunk[0]["start"]; end=chunk[-1]["end"]
        text=" ".join(w["word"] for w in chunk)
        lines.append(f"Dialogue: 0,{ass_time(start)},{ass_time(end)},Husan,,0,0,0,,{text}")
        i+=5
    Path(path).write_text("\n".join(lines),encoding="utf-8")

def final_render(input_path, out, ass=None):
    vf="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920:(in_w-out_w)/2+35*sin(t*0.8):(in_h-out_h)/2+25*cos(t*0.65)"
    if ass:
        vf += ",ass="+ass.replace("\\","/").replace(":","\\:")
    run(["ffmpeg","-y","-i",input_path,"-vf",vf,"-c:v","libx264","-preset","veryfast","-crf","20","-pix_fmt","yuv420p","-c:a","aac","-b:a","160k",out])

def pipeline(req):
    src=Path(req.input_path)
    if not src.exists():
        raise RuntimeError("Input video not found: "+str(src))
    work=src.parent/"HusanReels"
    work.mkdir(exist_ok=True)
    uid=uuid.uuid4().hex[:8]
    cut=work/f"{src.stem}_{uid}_cut.mp4"
    out=work/f"{src.stem}_{uid}_HUSAN_REEL.mp4"
    ass=None
    yield {"progress":5,"message":"Reading video…"}
    duration=ffprobe(str(src))
    yield {"progress":10,"message":"Transcribing with local Whisper…"}
    words=transcribe(str(src))
    yield {"progress":40,"message":"Building smart cuts…"}
    ranges=build_keep_ranges(words,duration,0.65 if req.mode=="smart" else 1.1)
    render_cut(str(src),ranges,str(cut))
    if req.captions:
        yield {"progress":58,"message":"Creating word-level captions…"}
        # Re-transcribe the cut video so timings match the edited timeline.
        cut_words=transcribe(str(cut))
        ass_path=work/f"{src.stem}_{uid}.ass"
        make_ass(cut_words,str(ass_path))
        ass=str(ass_path)
    yield {"progress":72,"message":"Building 9:16 motion frame…"}
    final_render(str(cut),str(out),ass)
    yield {"progress":98,"message":"Importing finished Reel…","output_path":str(out)}
    yield {"progress":100,"message":"Done.","output_path":str(out)}

@app.get("/health")
def health():
    return {"ok":True,"engine":"Husan Reels Local Engine","whisper":"faster-whisper"}

@app.post("/auto-edit")
def auto_edit(req: EditRequest):
    def events():
        try:
            for event in pipeline(req):
                yield json.dumps(event)+"\n"
        except Exception as e:
            yield json.dumps({"error":str(e)})+"\n"
    return StreamingResponse(events(),media_type="application/x-ndjson")
