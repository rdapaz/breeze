"""Generate Breeze Language Reference PDF from REFERENCE.md"""
import re
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.units import mm, cm
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, KeepTogether, HRFlowable, Preformatted
)
from reportlab.lib import colors
from xml.sax.saxutils import escape

OUTPUT = "D:/Work/Projects/breeze/Breeze_Reference.pdf"
INPUT = "D:/Work/Projects/breeze/REFERENCE.md"

# Colors
ACCENT = HexColor("#2563EB")       # blue
CODE_BG = HexColor("#F1F5F9")      # light gray
CODE_BORDER = HexColor("#CBD5E1")  # medium gray
DARK = HexColor("#1E293B")         # near black
MUTED = HexColor("#64748B")        # gray text

def build_styles():
    styles = getSampleStyleSheet()

    styles.add(ParagraphStyle(
        'DocTitle', parent=styles['Title'],
        fontSize=28, leading=34, textColor=ACCENT,
        spaceAfter=4, alignment=TA_LEFT,
    ))
    styles.add(ParagraphStyle(
        'Subtitle', parent=styles['Normal'],
        fontSize=11, leading=15, textColor=MUTED,
        spaceAfter=20,
    ))
    styles.add(ParagraphStyle(
        'H2', parent=styles['Heading2'],
        fontSize=18, leading=22, textColor=DARK,
        spaceBefore=22, spaceAfter=8,
        borderColor=ACCENT, borderWidth=0, borderPadding=0,
    ))
    styles.add(ParagraphStyle(
        'H3', parent=styles['Heading3'],
        fontSize=13, leading=17, textColor=ACCENT,
        spaceBefore=14, spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        'Body', parent=styles['Normal'],
        fontSize=10, leading=14, textColor=DARK,
        spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        'CodeBlock', parent=styles['Code'],
        fontSize=8.5, leading=12, textColor=HexColor("#334155"),
        backColor=CODE_BG, borderColor=CODE_BORDER,
        borderWidth=0.5, borderPadding=8, borderRadius=3,
        leftIndent=8, rightIndent=8,
        spaceBefore=4, spaceAfter=10,
        fontName='Courier',
    ))
    styles.add(ParagraphStyle(
        'InlineCode', parent=styles['Normal'],
        fontSize=9, fontName='Courier', textColor=HexColor("#BE185D"),
    ))
    styles.add(ParagraphStyle(
        'BzBullet', parent=styles['Normal'],
        fontSize=10, leading=14, textColor=DARK,
        leftIndent=20, bulletIndent=8, spaceAfter=3,
        bulletFontName='Helvetica', bulletFontSize=10,
    ))
    styles.add(ParagraphStyle(
        'TOCEntry', parent=styles['Normal'],
        fontSize=10, leading=18, textColor=ACCENT,
        leftIndent=12,
    ))
    styles.add(ParagraphStyle(
        'TableCell', parent=styles['Normal'],
        fontSize=8.5, leading=12, textColor=DARK,
    ))
    styles.add(ParagraphStyle(
        'Blockquote', parent=styles['Normal'],
        fontSize=9.5, leading=14, textColor=MUTED,
        leftIndent=16, borderColor=ACCENT, borderWidth=0,
        spaceBefore=6, spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        'Footer', parent=styles['Normal'],
        fontSize=8, textColor=MUTED, alignment=TA_CENTER,
    ))
    return styles

def fmt_inline(text, styles):
    """Convert inline markdown to reportlab XML."""
    # Escape XML
    text = escape(text)
    # Bold
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    # Inline code
    text = re.sub(r'`([^`]+)`', r'<font face="Courier" size="9" color="#BE185D">\1</font>', text)
    # Links (just show text)
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    return text

def parse_md(md_text, styles):
    """Parse markdown into reportlab flowables."""
    story = []
    lines = md_text.split('\n')
    i = 0
    in_code = False
    code_lines = []

    while i < len(lines):
        line = lines[i]

        # Code block toggle
        if line.startswith('```'):
            if in_code:
                # End code block
                code_text = '\n'.join(code_lines)
                code_text = escape(code_text)
                code_text = code_text.replace(' ', '&nbsp;')
                code_text = code_text.replace('\n', '<br/>')
                story.append(Paragraph(code_text, styles['CodeBlock']))
                code_lines = []
                in_code = False
            else:
                in_code = True
                code_lines = []
            i += 1
            continue

        if in_code:
            code_lines.append(line)
            i += 1
            continue

        # Blank line
        if not line.strip():
            i += 1
            continue

        # Horizontal rule
        if line.strip() == '---':
            story.append(Spacer(1, 6))
            story.append(HRFlowable(
                width="100%", thickness=0.5, color=CODE_BORDER,
                spaceBefore=4, spaceAfter=8
            ))
            i += 1
            continue

        # H1
        if line.startswith('# ') and not line.startswith('## '):
            text = line[2:].strip()
            story.append(Paragraph(fmt_inline(text, styles), styles['DocTitle']))
            i += 1
            continue

        # H2
        if line.startswith('## '):
            text = line[3:].strip()
            story.append(Spacer(1, 4))
            story.append(HRFlowable(
                width="100%", thickness=1.5, color=ACCENT,
                spaceBefore=2, spaceAfter=2
            ))
            story.append(Paragraph(fmt_inline(text, styles), styles['H2']))
            i += 1
            continue

        # H3
        if line.startswith('### '):
            text = line[4:].strip()
            story.append(Paragraph(fmt_inline(text, styles), styles['H3']))
            i += 1
            continue

        # Blockquote
        if line.startswith('> '):
            text = line[2:].strip()
            story.append(Paragraph(fmt_inline(text, styles), styles['Blockquote']))
            i += 1
            continue

        # Bullet list
        if line.startswith('- '):
            text = line[2:].strip()
            story.append(Paragraph(
                fmt_inline(text, styles), styles['BzBullet'],
                bulletText='\u2022'
            ))
            i += 1
            continue

        # Table
        if '|' in line and i + 1 < len(lines) and '---' in lines[i + 1]:
            # Collect table rows
            table_rows = []
            # Header
            cells = [c.strip() for c in line.split('|')[1:-1]]
            table_rows.append(cells)
            i += 1  # skip separator line
            i += 1
            while i < len(lines) and '|' in lines[i]:
                cells = [c.strip() for c in lines[i].split('|')[1:-1]]
                table_rows.append(cells)
                i += 1

            # Build table
            if table_rows:
                col_count = len(table_rows[0])
                avail = A4[0] - 50 * mm
                col_widths = [avail / col_count] * col_count

                data = []
                for ri, row in enumerate(table_rows):
                    styled_row = []
                    for cell in row:
                        st = styles['TableCell']
                        styled_row.append(Paragraph(fmt_inline(cell, styles), st))
                    data.append(styled_row)

                t = Table(data, colWidths=col_widths, repeatRows=1)
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), ACCENT),
                    ('TEXTCOLOR', (0, 0), (-1, 0), white),
                    ('FONTSIZE', (0, 0), (-1, 0), 9),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('BACKGROUND', (0, 1), (-1, -1), white),
                    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, CODE_BG]),
                    ('GRID', (0, 0), (-1, -1), 0.5, CODE_BORDER),
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                    ('TOPPADDING', (0, 0), (-1, -1), 5),
                    ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
                    ('LEFTPADDING', (0, 0), (-1, -1), 6),
                    ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ]))
                story.append(t)
                story.append(Spacer(1, 8))
            continue

        # Italic standalone line
        if line.startswith('*') and line.endswith('*') and not line.startswith('**'):
            text = line.strip('*').strip()
            story.append(Spacer(1, 8))
            story.append(Paragraph(f'<i>{escape(text)}</i>', styles['Blockquote']))
            i += 1
            continue

        # Regular paragraph
        text = fmt_inline(line.strip(), styles)
        story.append(Paragraph(text, styles['Body']))
        i += 1

    return story

def add_page_number(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MUTED)
    canvas.drawCentredString(A4[0] / 2, 15 * mm, f"Breeze Language Reference  |  Page {doc.page}")
    canvas.restoreState()

def main():
    with open(INPUT, 'r', encoding='utf-8') as f:
        md_text = f.read()

    styles = build_styles()

    doc = SimpleDocTemplate(
        OUTPUT, pagesize=A4,
        leftMargin=25 * mm, rightMargin=25 * mm,
        topMargin=20 * mm, bottomMargin=25 * mm,
        title="Breeze Language Reference",
        author="Breeze",
    )

    story = []

    # Subtitle after title will be injected by markdown parsing
    # but let's add version info
    story += parse_md(md_text, styles)

    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(f"PDF generated: {OUTPUT}")

if __name__ == '__main__':
    main()
