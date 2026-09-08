from pathlib import Path
import textwrap

import fitz


ROOT = Path(__file__).resolve().parents[1]
SOURCE_MD = ROOT / "security-reports" / "documentation-upload-2026-08-24-0.14.0.1" / "agentexchange" / "TwinaForms_AgentExchange_Solution_Intake_Questionnaire_Answers_2026-08-31.md"
PACKET_PDF = ROOT / "security-reports" / "documentation-upload-2026-08-24-0.14.0.1" / "agentexchange" / "TwinaForms_AgentExchange_Solution_Intake_Questionnaire_Answers_2026-08-31.pdf"
OUTPUT_PDF = ROOT / "output" / "pdf" / "TwinaForms_AgentExchange_Solution_Intake_Questionnaire_Answers_2026-08-31.pdf"
RENDER_DIR = ROOT / "tmp" / "pdfs" / "agentexchange-questionnaire-render"


PAGE_W, PAGE_H = fitz.paper_size("letter")
MARGIN_X = 54
MARGIN_TOP = 54
MARGIN_BOTTOM = 48
BODY_SIZE = 9.5
H1_SIZE = 17
H2_SIZE = 12.5
H3_SIZE = 10.5
LINE_H = 13
CODE_FONT = "courier"
BODY_FONT = "helv"
BOLD_FONT = "helv"


def parse_blocks(text: str):
    blocks = []
    table = []
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("|") and line.endswith("|"):
            table.append(line)
            continue
        if table:
            blocks.append(("table", table))
            table = []
        if not line:
            blocks.append(("blank", ""))
        elif line.startswith("# "):
            blocks.append(("h1", line[2:].strip()))
        elif line.startswith("## "):
            blocks.append(("h2", line[3:].strip()))
        elif line.startswith("### "):
            blocks.append(("h3", line[4:].strip()))
        elif line.startswith("- "):
            blocks.append(("bullet", line[2:].strip()))
        elif len(line) > 2 and line[0].isdigit() and line[1:3] == ". ":
            blocks.append(("number", line.strip()))
        else:
            blocks.append(("p", line.strip()))
    if table:
        blocks.append(("table", table))
    return blocks


def clean_inline(value: str) -> str:
    return value.replace("`", "")


class PdfWriter:
    def __init__(self):
        self.doc = fitz.open()
        self.page = None
        self.y = MARGIN_TOP
        self.page_no = 0
        self.new_page()

    def new_page(self):
        self.page = self.doc.new_page(width=PAGE_W, height=PAGE_H)
        self.page_no += 1
        self.y = MARGIN_TOP
        footer = f"TwinaForms AgentExchange Questionnaire Answers - Page {self.page_no}"
        self.page.insert_text((MARGIN_X, PAGE_H - 28), footer, fontsize=8, fontname=BODY_FONT, color=(0.35, 0.35, 0.35))

    def ensure(self, height):
        if self.y + height > PAGE_H - MARGIN_BOTTOM:
            self.new_page()

    def text(self, value, size=BODY_SIZE, font=BODY_FONT, indent=0, gap_after=5, color=(0.08, 0.08, 0.08), wrap_chars=92):
        value = clean_inline(value)
        width_chars = max(28, wrap_chars - int(indent / 5))
        lines = []
        for part in value.split("\n"):
            wrapped = textwrap.wrap(part, width=width_chars, break_long_words=False, replace_whitespace=False) or [""]
            lines.extend(wrapped)
        height = len(lines) * LINE_H + gap_after
        self.ensure(height)
        for line in lines:
            self.page.insert_text((MARGIN_X + indent, self.y), line, fontsize=size, fontname=font, color=color)
            self.y += LINE_H
        self.y += gap_after

    def table(self, rows):
        parsed = []
        for row in rows:
            cells = [cell.strip() for cell in row.strip("|").split("|")]
            if all(set(cell) <= set("-: ") for cell in cells):
                continue
            parsed.append(cells)
        if not parsed:
            return
        self.ensure(115)
        if len(parsed[0]) == 3:
            headers = parsed[0]
            body = parsed[1:]
            self.text(" | ".join(headers), size=8.8, font=BOLD_FONT, gap_after=2, wrap_chars=96)
            for cells in body:
                labels = ["Action Name", "Action Type", "Public Action Rationale"]
                for label, cell in zip(labels, cells):
                    self.text(f"{label}: {cell}", size=8.7, indent=12, gap_after=1, wrap_chars=88)
                self.y += 4
        else:
            for cells in parsed:
                self.text(" | ".join(cells), size=8.7, indent=10, wrap_chars=90)


def build_pdf():
    writer = PdfWriter()
    for kind, value in parse_blocks(SOURCE_MD.read_text(encoding="utf-8")):
        if kind == "blank":
            writer.y += 4
        elif kind == "h1":
            writer.text(value, size=H1_SIZE, font=BOLD_FONT, gap_after=9, wrap_chars=70)
        elif kind == "h2":
            writer.y += 4
            writer.text(value, size=H2_SIZE, font=BOLD_FONT, gap_after=7, wrap_chars=78)
        elif kind == "h3":
            writer.text(value, size=H3_SIZE, font=BOLD_FONT, gap_after=5, wrap_chars=82)
        elif kind == "bullet":
            writer.text("- " + value, indent=12, gap_after=3, wrap_chars=86)
        elif kind == "number":
            writer.text(value, indent=12, gap_after=3, wrap_chars=86)
        elif kind == "table":
            writer.table(value)
        else:
            writer.text(value, wrap_chars=92)

    PACKET_PDF.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    writer.doc.save(PACKET_PDF)
    writer.doc.save(OUTPUT_PDF)
    writer.doc.close()


def render_pdf():
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(PACKET_PDF)
    for i, page in enumerate(doc, 1):
        pix = page.get_pixmap(matrix=fitz.Matrix(1.3, 1.3), alpha=False)
        pix.save(RENDER_DIR / f"page-{i:02d}.png")
    doc.close()


if __name__ == "__main__":
    build_pdf()
    render_pdf()
    print(PACKET_PDF)
    print(OUTPUT_PDF)
    print(RENDER_DIR)
