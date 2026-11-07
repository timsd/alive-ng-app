o# ALIVE Nigeria Tract PDF & Interactive Lesson Extractor Guide

## 1. Executive Summary: Audit of Previous vs. Enhanced Extractor

Before this enhancement, we audited how uploaded Tract PDFs were converted into Interactive Lessons:

| Capability | Previous `PdfExtractorService` | Enhanced `PdfExtractorService` (Now Active) |
| :--- | :--- | :--- |
| **Raw PDF Text Extraction** | Extracted plain text using `syncfusion_flutter_pdf` | Extracts text & normalizes hyphenated line-wraps |
| **Question & Section Detection** | Basic heading split only (`questions: []` was empty) | Full regex detection (`1.`, `Question 1`, `Q1`, `##`, `?`) into `ExtractedLessonSection` items |
| **Scripture Reference Extraction** | None in dynamic extractor | Full 66-book Bible regex (`2 Timothy 3:16`, `Matthew 4:4, 7, 10`, etc.) rendered as clickable chips opening `BibleReferenceModalSheet` (all 9 Bible versions) |
| **Quoted Verse Cards** | Hardcoded only in Lesson 1 | Automatically extracts `"Quote..." (Book Ch:V)` into accented quote cards |
| **Interactive Reader Routing** | Only Lesson 1 opened `InteractiveLessonReaderScreen`; admin-uploaded lessons fell back to plain `TractReaderScreen` | **All** admin-uploaded lessons now open `InteractiveLessonReaderScreen` with reflection inputs, progress tracking, and **Discipleship Tracker integration** |
| **Dynamic Brand Colour Formatting** | Single static green (`#166534`) | **6 Curated ALIVE Nigeria Brand Palettes** randomly/deterministically assigned per lesson and rotated across sections |

---

## 2. Curated ALIVE Nigeria Dynamic Colour Palettes

Both the in-app Dart extractor ([`lib/services/pdf_extractor_service.dart`](file:///c:/Users/Timothy%20Olodude/Documents/ZavTech%20Projects/alive-ng-app/lib/services/pdf_extractor_service.dart)) and the standalone Python `PyMuPDF` extractor below share 6 harmonious brand colour palettes that match the ALIVE Nigeria aesthetic:

| Palette ID | Theme Name | Primary Hex | Dark Gradient (`Start` → `End`) | Accent Hex | Light Card Tint | Dark Card Tint |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `emerald_forest` | **Emerald Forest** | `#166534` | `#14532D` → `#064E3B` | `#F59E0B` | `#F0FDF4` | `#14241B` |
| `royal_sapphire` | **Royal Sapphire** | `#233E5F` | `#1E3A8A` → `#172554` | `#E5B94D` | `#EFF6FF` | `#131E33` |
| `divine_gold` | **Divine Gold & Bronze** | `#B45309` | `#78350F` → `#451A03` | `#10B981` | `#FFFBEB` | `#261C10` |
| `teal_covenant` | **Teal Covenant** | `#0F766E` | `#115E59` → `#134E4A` | `#FBBF24` | `#F0FDFA` | `#112625` |
| `crimson_grace` | **Crimson Grace** | `#9F1239` | `#881337` → `#4C0519` | `#F59E0B` | `#FFF1F2` | `#281118` |
| `indigo_prophecy` | **Indigo Prophecy** | `#3730A3` | `#312E81` → `#1E1B4B` | `#34D399` | `#EEF2FF` | `#171630` |

---

## 3. In-App Flutter / Dart Extractor (`lib/services/pdf_extractor_service.dart`)

This is the live extractor wired directly into [`TractPodcastAdminScreen`](file:///c:/Users/Timothy%20Olodude/Documents/ZavTech%20Projects/alive-ng-app/lib/screens/admin/tract_podcast_admin_screen.dart) and [`InteractiveLessonReaderScreen`](file:///c:/Users/Timothy%20Olodude/Documents/ZavTech%20Projects/alive-ng-app/lib/screens/lessons/interactive_lesson_reader_screen.dart) when an Admin uploads a Tract PDF:

```dart
import 'dart:convert';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

class LessonColorPalette {
  final String id;
  final String name;
  final int primaryHex;
  final int darkGradientStartHex;
  final int darkGradientEndHex;
  final int accentHex;
  final int lightTintHex;
  final int darkTintHex;

  const LessonColorPalette({
    required this.id,
    required this.name,
    required this.primaryHex,
    required this.darkGradientStartHex,
    required this.darkGradientEndHex,
    required this.accentHex,
    required this.lightTintHex,
    required this.darkTintHex,
  });

  static const List<LessonColorPalette> brandPalettes = [
    LessonColorPalette(
      id: 'emerald_forest',
      name: 'Emerald Forest',
      primaryHex: 0xFF166534,
      darkGradientStartHex: 0xFF14532D,
      darkGradientEndHex: 0xFF064E3B,
      accentHex: 0xFFF59E0B,
      lightTintHex: 0xFFF0FDF4,
      darkTintHex: 0xFF14241B,
    ),
    LessonColorPalette(
      id: 'royal_sapphire',
      name: 'Royal Sapphire',
      primaryHex: 0xFF233E5F,
      darkGradientStartHex: 0xFF1E3A8A,
      darkGradientEndHex: 0xFF172554,
      accentHex: 0xFFE5B94D,
      lightTintHex: 0xFFEFF6FF,
      darkTintHex: 0xFF131E33,
    ),
    LessonColorPalette(
      id: 'divine_gold',
      name: 'Divine Gold & Bronze',
      primaryHex: 0xFFB45309,
      darkGradientStartHex: 0xFF78350F,
      darkGradientEndHex: 0xFF451A03,
      accentHex: 0xFF10B981,
      lightTintHex: 0xFFFFFBEB,
      darkTintHex: 0xFF261C10,
    ),
    LessonColorPalette(
      id: 'teal_covenant',
      name: 'Teal Covenant',
      primaryHex: 0xFF0F766E,
      darkGradientStartHex: 0xFF115E59,
      darkGradientEndHex: 0xFF134E4A,
      accentHex: 0xFFFBBF24,
      lightTintHex: 0xFFF0FDFA,
      darkTintHex: 0xFF112625,
    ),
    LessonColorPalette(
      id: 'crimson_grace',
      name: 'Crimson Grace',
      primaryHex: 0xFF9F1239,
      darkGradientStartHex: 0xFF881337,
      darkGradientEndHex: 0xFF4C0519,
      accentHex: 0xFFF59E0B,
      lightTintHex: 0xFFFFF1F2,
      darkTintHex: 0xFF281118,
    ),
    LessonColorPalette(
      id: 'indigo_prophecy',
      name: 'Indigo Prophecy',
      primaryHex: 0xFF3730A3,
      darkGradientStartHex: 0xFF312E81,
      darkGradientEndHex: 0xFF1E1B4B,
      accentHex: 0xFF34D399,
      lightTintHex: 0xFFEEF2FF,
      darkTintHex: 0xFF171630,
    ),
  ];
}
```

---

## 4. Enhanced Standalone Python `PyMuPDF` (`fitz`) Extractor with Dynamic Brand Colours

Below is the enhanced version of your Python extractor script (`pdf_tract_extractor.py`). It extracts images, numbered study sections, quoted scriptures, and clickable Bible references, assigns dynamic ALIVE Nigeria colour palettes per section, outputs the exact JSON schema compatible with Flutter (`tract_data.json`), and generates a multi-palette interactive HTML preview (`index.html`):

```python
import os
import re
import json
import random
import fitz  # PyMuPDF
from pathlib import Path

# Curated ALIVE Nigeria Brand Colour Palettes
BRAND_PALETTES = [
    {
        "id": "emerald_forest",
        "name": "Emerald Forest",
        "primary": "#166534",
        "gradient_start": "#14532D",
        "gradient_end": "#064E3B",
        "accent": "#F59E0B",
        "card_bg_dark": "#14241B",
        "card_bg_light": "#F0FDF4",
        "badge_bg": "#064E3B",
        "badge_text": "#6EE7B7",
    },
    {
        "id": "royal_sapphire",
        "name": "Royal Sapphire",
        "primary": "#233E5F",
        "gradient_start": "#1E3A8A",
        "gradient_end": "#172554",
        "accent": "#E5B94D",
        "card_bg_dark": "#131E33",
        "card_bg_light": "#EFF6FF",
        "badge_bg": "#1E3A8A",
        "badge_text": "#93C5FD",
    },
    {
        "id": "divine_gold",
        "name": "Divine Gold & Bronze",
        "primary": "#B45309",
        "gradient_start": "#78350F",
        "gradient_end": "#451A03",
        "accent": "#10B981",
        "card_bg_dark": "#261C10",
        "card_bg_light": "#FFFBEB",
        "badge_bg": "#78350F",
        "badge_text": "#FCD34D",
    },
    {
        "id": "teal_covenant",
        "name": "Teal Covenant",
        "primary": "#0F766E",
        "gradient_start": "#115E59",
        "gradient_end": "#134E4A",
        "accent": "#FBBF24",
        "card_bg_dark": "#112625",
        "card_bg_light": "#F0FDFA",
        "badge_bg": "#115E59",
        "badge_text": "#5EEAD4",
    },
    {
        "id": "crimson_grace",
        "name": "Crimson Grace",
        "primary": "#9F1239",
        "gradient_start": "#881337",
        "gradient_end": "#4C0519",
        "accent": "#F59E0B",
        "card_bg_dark": "#281118",
        "card_bg_light": "#FFF1F2",
        "badge_bg": "#881337",
        "badge_text": "#FDA4AF",
    },
    {
        "id": "indigo_prophecy",
        "name": "Indigo Prophecy",
        "primary": "#3730A3",
        "gradient_start": "#312E81",
        "gradient_end": "#1E1B4B",
        "accent": "#34D399",
        "card_bg_dark": "#171630",
        "card_bg_light": "#EEF2FF",
        "badge_bg": "#312E81",
        "badge_text": "#A5B4FC",
    },
]

SCRIPTURE_REGEX = re.compile(
    r"\b((?:[1-3]\s*)?[A-Z][a-z]+\s+\d+:\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)\b"
)
QUESTION_REGEX = re.compile(
    r"^(\d+[\.\)]|\bQuestion\s+\d+|\bQ\d+)", re.IGNORECASE
)


def extract_pdf_tract(pdf_path: str, output_dir: str = "tract_output"):
    """
    Extracts text, numbered questions, scripture references, and images from a PDF tract,
    assigns dynamic ALIVE Nigeria brand colour palettes, and outputs both Flutter-ready JSON
    and a multi-theme interactive HTML study app.
    """
    out_path = Path(output_dir)
    images_dir = out_path / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(pdf_path)
    title = Path(pdf_path).stem.replace("_", " ")

    # Pick a random starting brand palette for this lesson, then rotate across sections
    start_palette_idx = random.randint(0, len(BRAND_PALETTES) - 1)
    hero_palette = BRAND_PALETTES[start_palette_idx]

    tract_data = {
        "title": title,
        "primary_palette": hero_palette,
        "images": [],
        "sections": [],
        "full_text": [],
    }

    image_counter = 0
    section_counter = 0

    for page_index in range(len(doc)):
        page = doc[page_index]

        # 1. Image Extraction
        for img_info in page.get_images(full=True):
            xref = img_info[0]
            base_image = doc.extract_image(xref)
            image_bytes = base_image["image"]
            image_ext = base_image["ext"]

            image_counter += 1
            image_filename = f"image_p{page_index+1}_{image_counter}.{image_ext}"
            image_filepath = images_dir / image_filename

            with open(image_filepath, "wb") as f_img:
                f_img.write(image_bytes)

            tract_data["images"].append(
                {"page": page_index + 1, "filename": f"images/{image_filename}"}
            )

        # 2. Structured Text & Colour Palette Assignment
        blocks = page.get_text("blocks")
        blocks.sort(key=lambda b: (b[1], b[0]))

        for block in blocks:
            text = block[4].strip()
            if not text:
                continue

            section_counter += 1
            is_question = bool(QUESTION_REGEX.match(text))
            scriptures = [m.group(1) for m in SCRIPTURE_REGEX.finditer(text)]
            is_scripture = len(scriptures) > 0
            palette = BRAND_PALETTES[
                (start_palette_idx + section_counter) % len(BRAND_PALETTES)
            ]

            tract_data["sections"].append(
                {
                    "number": section_counter,
                    "page": page_index + 1,
                    "text": text,
                    "is_question": is_question,
                    "is_scripture": is_scripture,
                    "scripture_references": scriptures,
                    "has_input_target": is_question or "?" in text,
                    "paletteId": palette["id"],
                    "palette": palette,
                }
            )
            tract_data["full_text"].append(text)

    json_path = out_path / "tract_data.json"
    with open(json_path, "w", encoding="utf-8") as jf:
        json.dump(tract_data, jf, indent=2, ensure_ascii=False)

    generate_html_app(tract_data, out_path / "index.html")
    print(f"Extracted {image_counter} images and {section_counter} themed sections to {out_path}")


def generate_html_app(data: dict, output_file: Path):
    hero = data["primary_palette"]
    cards_html = ""

    for idx, section in enumerate(data["sections"], start=1):
        pal = section["palette"]
        clean_text = section["text"].replace("\n", "<br>")
        refs_html = "".join(
            [
                f'<span class="scripture-badge" style="background:{pal["badge_bg"]};color:{pal["badge_text"]};">{ref}</span> '
                for ref in section.get("scripture_references", [])
            ]
        )

        if section["has_input_target"]:
            cards_html += f"""
      <div class="tract-card question-card" style="background:{pal['card_bg_dark']};border-left:4px solid {pal['primary']};">
        <div class="d-flex justify-content-between align-items-center mb-2">
          <span class="scripture-badge" style="background:{pal['badge_bg']};color:{pal['badge_text']};">
            Section {idx} • {pal['name']}
          </span>
          <div>{refs_html}</div>
        </div>
        <div class="fs-6 fw-medium text-white mb-2">{clean_text}</div>
        <label class="form-label text-secondary small">Your Answer / Reflection:</label>
        <textarea class="answer-input" id="q_{idx}" rows="2" placeholder="Type your response here..."></textarea>
      </div>"""
        else:
            cards_html += f"""
      <div class="tract-card" style="background:{pal['card_bg_dark']};border-left:3px solid {pal['accent']};">
        {f'<div class="mb-2">{refs_html}</div>' if refs_html else ''}
        <div class="text-light">{clean_text}</div>
      </div>"""

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{data['title']} - ALIVE Nigeria Interactive Study</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    body {{
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: #0b1312;
      color: #e5ece9;
      line-height: 1.6;
    }}
    .tract-container {{ max-width: 860px; margin: 0 auto; padding: 2rem 1rem; }}
    .app-header {{
      text-align: center;
      margin-bottom: 2rem;
      padding: 2.2rem 1.5rem;
      border-radius: 16px;
      background: linear-gradient(135deg, {hero['gradient_start']}, {hero['gradient_end']});
      border: 1px solid rgba(255,255,255,0.12);
    }}
    .tract-card {{
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 1.25rem;
      box-shadow: 0 4px 20px rgba(0,0,0,0.25);
    }}
    .answer-input {{
      background: rgba(0,0,0,0.35);
      border: 1px solid rgba(255,255,255,0.18);
      color: #f1f5f9;
      border-radius: 8px;
      padding: 0.75rem;
      width: 100%;
      margin-top: 0.5rem;
    }}
    .scripture-badge {{
      font-size: 0.78rem;
      font-weight: 600;
      padding: 3px 9px;
      border-radius: 6px;
      display: inline-block;
      margin-right: 4px;
    }}
    .btn-save {{
      background: {hero['accent']};
      border: none;
      color: #0f172a;
      font-weight: 700;
      padding: 0.6rem 1.5rem;
      border-radius: 8px;
    }}
  </style>
</head>
<body>
  <div class="tract-container">
    <div class="app-header">
      <h1 class="fw-bold text-white">{data['title']}</h1>
      <p class="text-light opacity-75">ALIVE Nigeria Dynamic Interactive Study ({hero['name']} Theme)</p>
      <button class="btn btn-save" onclick="saveAllResponses()">Save Answers Locally</button>
    </div>
    <div class="content-stream">{cards_html}</div>
  </div>
  <script>
    document.addEventListener("DOMContentLoaded", () => {{
      document.querySelectorAll(".answer-input").forEach(input => {{
        const saved = localStorage.getItem(input.id);
        if (saved) input.value = saved;
        input.addEventListener("input", e => localStorage.setItem(e.target.id, e.target.value));
      }});
    }});
    function saveAllResponses() {{
      const payload = {{}};
      document.querySelectorAll(".answer-input").forEach(input => payload[input.id] = input.value);
      const blob = new Blob([JSON.stringify(payload, null, 2)], {{ type: "application/json" }});
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "tract_answers.json";
      a.click();
    }}
  </script>
</body>
</html>"""

    with open(output_file, "w", encoding="utf-8") as hf:
        hf.write(html_content)


if __name__ == "__main__":
    import sys
    pdf_filename = sys.argv[1] if len(sys.argv) > 1 else "Lesson_1.pdf"
    if os.path.exists(pdf_filename):
        extract_pdf_tract(pdf_filename)
    else:
        print(f"File '{pdf_filename}' not found.")
```

