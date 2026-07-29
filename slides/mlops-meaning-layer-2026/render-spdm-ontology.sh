#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

FONT_CSS='"IBM Plex Sans JP","Hiragino Sans","Noto Sans JP",sans-serif'

npx --yes @mermaid-js/mermaid-cli -i spdm-ontology.mmd -o spdm-ontology.svg -b transparent

python3 <<'PY'
from pathlib import Path

font_css = '"IBM Plex Sans JP","Hiragino Sans","Noto Sans JP",sans-serif'
svg_path = Path("spdm-ontology.svg")

svg = svg_path.read_text()
svg = svg.replace(
    '--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif',
    f"--mermaid-font-family:{font_css}",
)
svg = svg.replace(
    "#my-svg{font-size:",
    f"#my-svg{{font-family:{font_css};font-size:",
)
svg = svg.replace(
    "#my-svg svg{font-size:",
    f"#my-svg svg{{font-family:{font_css};font-size:",
)
svg = svg.replace(
    "#my-svg .label text,#my-svg span{fill:#1a2332;color:#1a2332;}",
    f"#my-svg .label text,#my-svg span{{fill:#1a2332;color:#1a2332;font-family:{font_css};}}",
)
svg = svg.replace(
    '<svg id="my-svg"',
    '<svg class="diagram flowchart" id="my-svg"',
    1,
)
svg = svg.replace(' xmlns:xlink="http://www.w3.org/1999/xlink" class="flowchart"', ' xmlns:xlink="http://www.w3.org/1999/xlink"', 1)
svg_path.write_text(svg)
print("Rendered spdm-ontology.svg")
PY
