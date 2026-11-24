# Usage

[简体中文](USAGE.md) · English

The app's interface is in Chinese; labels are quoted as they appear in the app, with English in parentheses.

## Which folder to import

Pick a folder in the Files app. A work's folder name needs `RJ` plus 6–8 digits anywhere in it, in any letter case, for example `RJ01234567 Title` or `[Circle] RJ01234567`.

**One work**: pick the work's own folder.

```text
RJ01234567 Title/  ← pick this to import one work
```

**Many works**: pick a folder holding works; each RJ folder one level down is a work.

```text
ASMR/  ← pick this to import 3 works
├── RJ01234567 Title/
├── RJ01234568 Title/
└── [Circle] RJ01234569/
```

**Many works, grouped one level deeper**: works may sit two levels below the picked folder, but no deeper. Works and group folders can be mixed at the same level.

```text
ASMR/  ← pick this to import 3 works
├── Ear cleaning/
│   ├── RJ01234567 Title/
│   └── RJ01234568 Title/
└── Sleep/
    └── RJ01234569 Title/
```

Folders on 115 and WebDAV follow the same rules: open the folder in the 浏览 (Browse) tab and tap 导入此文件夹 (Import This Folder). Works already in the library are skipped, so after adding new works to a folder, just import it again.

## Inside a work and subtitles

Anything goes inside a work's folder: every audio, video, image, subtitle, text and PDF file is found recursively. Subtitles are matched to audio like this:

```text
RJ01234567 Title/
├── WAV/
│   ├── 01 Intro.wav
│   ├── 01 Intro.wav.vtt  ← matched: the audio file name plus a subtitle extension (DLsite style)
│   ├── 02 Main.wav
│   └── 02 Main.srt  ← matched: same name as the audio, different extension
├── MP3/  ← with several track folders, the work page opens the main one; switch any time
│   └── …
└── Subtitles/
    └── 01 Intro.vtt  ← not matched: not in the same folder as the audio
```

- A subtitle must sit in the **same folder** as its audio, with a matching name. srt / lrc / vtt / ass / ssa are supported; UTF-8, UTF-16, Shift-JIS and GB18030 text are detected automatically.
- When a track has both an srt / vtt / lrc and an ass / ssa, the former wins.
- Unmatched subtitles can still be opened from 全部文件 (All Files) on the work page. After fixing a name or location, choose ⋯ → 重新扫描此作品 (Rescan This Work) on the work page to match them again.

## Backups and re-signing

- A backup folder holds credentials in plain text (115 cookie, WebDAV passwords, LLM API keys). Keep it private.
- A new signing certificate or Bundle ID makes a different app, and data does not carry over: export a backup from the old app and restore it in the new one. After restoring, import each local folder again to re-grant access.
