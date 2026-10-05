# Husan Reels Master

One-click local AI montage for After Effects.

## Eng oson o'rnatish — bitta PowerShell komandasi

PowerShellni oching va shuni **to'liq** qo'ying:

```powershell
Set-ExecutionPolicy -Scope Process Bypass; iwr "https://raw.githubusercontent.com/sadullayevhusan78-a11y/HusanPLUGIN/main/install.ps1" -OutFile "$env:TEMP\husan-install.ps1"; & "$env:TEMP\husan-install.ps1"
```

Installer avtomatik:

- GitHubdan pluginni `Documents\Husan Reels Master` papkasiga clone qiladi
- keyingi ishga tushirishlarda `git pull --ff-only` bilan yangilaydi
- UXP Developer Mode'ni yoqadi
- Python virtual environment yaratadi
- AI engine dependencylarini o'rnatadi
- FFmpeg/ffprobe'ni tekshiradi va Winget mavjud bo'lsa o'rnatishga urinadi
- local AI serverni ishga tushiradi
- UXP Developer Tool o'rnatilgan bo'lsa ochadi

### After Effectsga birinchi ulash

Adobe UXP'ning development workflow'i sabab birinchi marta UXP Developer Tool ichida:

1. **Add Plugin**
2. `Documents\Husan Reels Master` papkasini tanlang
3. **Load & Watch**
4. After Effectsni oching
5. **Husan Reels Master** panelini oching

Keyin video layerni tanlab **AUTO MONTAGE** bosing.

> Muhim: PowerShell plugin fayllarini avtomatik tayyorlaydi va UDTni ochadi, lekin Adobe'ning development pluginini AE'ga birinchi marta yuklash bosqichi UXP Developer Tool orqali qilinadi.

## Nima qiladi

After Effects UXP panel -> localhost:8765 -> Python/Faster-Whisper + FFmpeg -> finished MP4 -> After Effects.

Video lokal kompyuterda qoladi.

Current pipeline:

- local Faster-Whisper transcription
- word-level timestamps
- smart dead-air removal
- 9:16 vertical output
- moving crop / punch-in
- caption rendering
- H.264/AAC MP4
- automatic import into active AE composition
- basic AE motion presets

## Open-source research

Architecture was informed by open-source local video-editing projects including QMM AutoEdit, AutoClip Core, Cut/Storm, and After Effects AutoCaptions.

We do not copy arbitrary repositories wholesale. Only license-compatible code may be reused directly; otherwise the idea is implemented independently. Third-party notices/licenses should be preserved when their code is incorporated.

## Roadmap

- face-aware reframing
- stronger word-by-word karaoke highlight
- filler-word detection
- retake detection
- automatic hook selection
- beat/SFX sync
- B-roll slots
- more motion presets
- direct AE motion-layer generation
