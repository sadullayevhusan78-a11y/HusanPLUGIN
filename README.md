# Husan Reels Master

One-click local AI montage for After Effects.

Select a video layer, press AUTO MONTAGE, and the local engine transcribes, cuts pauses, reframes to 9:16, adds captions, applies a subtle moving crop, renders MP4, and imports the finished Reel back into After Effects.

## Architecture

After Effects UXP panel -> localhost:8765 -> Python/Faster-Whisper + FFmpeg -> finished MP4 -> After Effects.

The video stays on the computer.

## Windows setup

1. Install Python 3.11.
2. Install FFmpeg and make sure ffmpeg and ffprobe work in CMD.
3. Open the plugin folder.
4. Run start_server.bat.
5. Load the UXP plugin in Adobe UXP Developer Tool.
6. Open After Effects and select a video layer.
7. Press AUTO MONTAGE.

The first run downloads the Whisper model and can take a while. Later runs reuse the local model.

## Current automatic pipeline

- local Faster-Whisper transcription
- word-level timestamps
- smart dead-air removal
- 9:16 vertical output
- subtle moving crop / punch-in
- caption rendering
- H.264/AAC MP4
- automatic import into the active AE composition

## Open-source research

The architecture was informed by open-source local video-editing projects including QMM AutoEdit, AutoClip Core, Cut/Storm, and After Effects AutoCaptions. Their documented approaches helped shape the pipeline.

We do not copy arbitrary repositories wholesale. Only code whose license and compatibility permit reuse should be incorporated directly; otherwise the same idea is implemented independently.

## Roadmap

- face-aware reframing
- real word-by-word karaoke highlight
- filler-word detection
- retake detection
- automatic hook selection
- beat/SFX sync
- B-roll slots
- more motion presets
- direct AE motion-layer generation
