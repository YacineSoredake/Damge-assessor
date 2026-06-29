"""
reporter.py — Multi-angle PDF report, DZD currency, Algeria context.
Now includes real bounding-box crop thumbnails per damage entry.
Returns raw bytes — nothing written to disk.
"""

import io, base64, random, string
from datetime import datetime
from PIL import Image, ImageDraw
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                 Image as RLImage, PageBreak, HRFlowable,
                                 KeepTogether)
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
from reportlab.pdfgen import canvas as pdfcanvas
from schemas import DamageDetail, AngleResult

# ── Palette ───────────────────────────────────────────────────────
NAVY    = colors.HexColor("#0F172A")
SLATE   = colors.HexColor("#475569")
LIGHT   = colors.HexColor("#F1F5F9")
ACCENT  = colors.HexColor("#2563EB")
GREEN   = colors.HexColor("#16A34A")
ORANGE  = colors.HexColor("#EA580C")
RED     = colors.HexColor("#DC2626")
BORDER  = colors.HexColor("#E2E8F0")
YELLOW  = colors.HexColor("#F59E0B")
WHITE   = colors.white
PURPLE  = colors.HexColor("#7C3AED")

# YOLO damage class colors (match detector.py)
YOLO_COLORS = {
    "scratch":     colors.HexColor("#3498DB"),
    "dent":        colors.HexColor("#E67E22"),
    "crack":       colors.HexColor("#E74C3C"),
    "paint":       colors.HexColor("#9B59B6"),
}

SEV_C  = {"minor":GREEN,"moderate":ORANGE,"severe":RED,"critical":RED}
COND_C = {"excellent":GREEN,"good":GREEN,"fair":ORANGE,"poor":RED,"critical":RED}
PRI_C  = {"urgent":RED,"high":ORANGE,"medium":ACCENT,"low":GREEN}

ANGLE_DISPLAY = {
    "front":"FRONT","rear":"REAR","left":"LEFT SIDE","right":"RIGHT SIDE",
    "closeup_1":"CLOSE-UP 1","closeup_2":"CLOSE-UP 2","closeup_3":"CLOSE-UP 3",
    "closeup_4":"CLOSE-UP 4","closeup_5":"CLOSE-UP 5",
}

def S(name, **kw): return ParagraphStyle(name, **kw)

W = 174*mm  # usable width

def b64_to_pil(b64: str) -> Image.Image:
    return Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")

def pil_to_rl(img: Image.Image, maxw_mm: float, maxh_mm: float) -> RLImage:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    ri = RLImage(buf)
    ri._restrictSize(maxw_mm*mm, maxh_mm*mm)
    return ri

def b64_to_rl(b64: str, maxw_mm: float, maxh_mm: float) -> RLImage:
    return pil_to_rl(b64_to_pil(b64), maxw_mm, maxh_mm)

def divider(thick=0.75, col=BORDER):
    return HRFlowable(width="100%", thickness=thick, color=col, spaceAfter=8)

def badge(text, bg):
    return Table([[Paragraph(text.upper(),
                             S("bg", fontSize=9, textColor=WHITE, fontName="Helvetica-Bold",
                               alignment=TA_CENTER))]],
                 style=[("BACKGROUND",(0,0),(-1,-1),bg),
                        ("TOPPADDING",(0,0),(-1,-1),5),("BOTTOMPADDING",(0,0),(-1,-1),5),
                        ("LEFTPADDING",(0,0),(-1,-1),10),("RIGHTPADDING",(0,0),(-1,-1),10)])

def footer_fn(canvas_obj, doc):
    canvas_obj.saveState()
    canvas_obj.setStrokeColor(BORDER)
    canvas_obj.line(18*mm, 15*mm, A4[0]-18*mm, 15*mm)
    canvas_obj.setFont("Helvetica", 8)
    canvas_obj.setFillColor(SLATE)
    canvas_obj.drawString(18*mm, 10*mm, "CarCheck — Automated Vehicle Damage Assessment | Algeria")
    canvas_obj.drawRightString(A4[0]-18*mm, 10*mm, f"Page {doc.page}")
    canvas_obj.restoreState()

def _draw_single_box(pil_img: Image.Image, bbox_norm: list, color_hex: str) -> Image.Image:
    """Draw a highlighted bounding box on a copy of the image."""
    W, H   = pil_img.size
    draw   = ImageDraw.Draw(pil_img)
    x1 = int(bbox_norm[0] * W)
    y1 = int(bbox_norm[1] * H)
    x2 = int(bbox_norm[2] * W)
    y2 = int(bbox_norm[3] * H)
    # Parse hex color
    hx  = color_hex.lstrip("#")
    rgb = tuple(int(hx[i:i+2], 16) for i in (0, 2, 4))
    for t in range(4):
        draw.rectangle([x1-t, y1-t, x2+t, y2+t], outline=rgb, width=1)
    return pil_img

def _crop_for_pdf(base_b64: str, bbox_norm: list, yolo_class: str,
                  maxw_mm: float = 40, maxh_mm: float = 30) -> RLImage | None:
    """
    Extract the damage region from the original image (decoded from b64)
    and return it as a ReportLab Image object, or None if the crop is too tiny.
    """
    if not base_b64 or not bbox_norm or len(bbox_norm) < 4:
        return None
    try:
        pil = b64_to_pil(base_b64)
        W, H = pil.size
        pad  = 0.02
        x1 = max(0, int((bbox_norm[0]-pad) * W))
        y1 = max(0, int((bbox_norm[1]-pad) * H))
        x2 = min(W, int((bbox_norm[2]+pad) * W))
        y2 = min(H, int((bbox_norm[3]+pad) * H))
        if (x2 - x1) < 10 or (y2 - y1) < 10:
            return None
        crop = pil.crop([x1, y1, x2, y2])
        # Draw a subtle border on the crop thumbnail
        hex_c = {"scratch":"#3498DB","dent":"#E67E22",
                  "crack":"#E74C3C","paint":"#9B59B6"}.get(yolo_class,"#2563EB")
        crop = _draw_single_box(crop, [0,0,1,1], hex_c)
        return pil_to_rl(crop, maxw_mm, maxh_mm)
    except Exception:
        return None


def build_pdf(overview: dict, angle_results: list[AngleResult],
              all_damages: list[DamageDetail]) -> bytes:

    REF  = "DAR-" + "".join(random.choices(string.ascii_uppercase+"0123456789", k=8))
    DATE = datetime.now().strftime("%d %B %Y  —  %H:%M")

    # Build angle→annotated_b64 lookup for crop extraction
    angle_b64_map = {ar.angle: ar.annotated_image_base64 for ar in angle_results}

    buf = io.BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4,
                            topMargin=0, bottomMargin=22*mm,
                            leftMargin=18*mm, rightMargin=18*mm)

    sTitle  = S("T",  fontSize=22, textColor=WHITE, fontName="Helvetica-Bold")
    sSub    = S("Su", fontSize=9,  textColor=colors.HexColor("#CBD5E1"),
                alignment=TA_RIGHT, leading=13)
    sH1     = S("H1", fontSize=13, textColor=NAVY, fontName="Helvetica-Bold",
                spaceBefore=4, spaceAfter=4)
    sH2     = S("H2", fontSize=11, textColor=NAVY, fontName="Helvetica-Bold",
                spaceBefore=3, spaceAfter=2)
    sBody   = S("B",  fontSize=9,  textColor=SLATE, leading=14, spaceAfter=2)
    sLabel  = S("L",  fontSize=8,  textColor=SLATE, fontName="Helvetica-Bold")
    sValue  = S("V",  fontSize=10, textColor=NAVY,  fontName="Helvetica-Bold")
    sMono   = S("M",  fontSize=8,  fontName="Courier", textColor=SLATE)

    story = []

    # ══ HEADER ════════════════════════════════════════════════════
    hdr = Table([[
        Paragraph("CarCheck", sTitle),
        Paragraph(f"Damage Assessment Report<br/>{DATE}<br/>Ref: <b>{REF}</b>", sSub)
    ]], colWidths=[100*mm, 74*mm],
       style=[("BACKGROUND",(0,0),(-1,-1),NAVY),
              ("VALIGN",(0,0),(-1,-1),"MIDDLE"),
              ("TOPPADDING",(0,0),(-1,-1),18),("BOTTOMPADDING",(0,0),(-1,-1),18),
              ("LEFTPADDING",(0,0),(0,0),18),("RIGHTPADDING",(-1,0),(-1,0),18)])
    story += [hdr, Spacer(1,14)]

    # ══ PHOTO GRID (main angles, annotated with all boxes) ════════
    main_angles = [ar for ar in angle_results if not ar.angle.startswith("closeup")][:4]
    if main_angles:
        pairs = [main_angles[i:i+2] for i in range(0, len(main_angles), 2)]
        for pair in pairs:
            row = []
            for ar in pair:
                lbl   = ANGLE_DISPLAY.get(ar.angle, ar.angle.upper())
                # Tally string: "dent×2  scratch×1"
                tally = "  ".join(f"{k}×{v}" for k, v in sorted(ar.all_probs.items()))
                cell  = [
                    b64_to_rl(ar.annotated_image_base64, 82, 54),
                    Paragraph(f"<b>{lbl}</b>  ·  {ar.damage_count} detection(s)",
                              S("al", fontSize=8, fontName="Helvetica-Bold", textColor=NAVY)),
                    Paragraph(tally or "—",
                              S("tl", fontSize=7.5, textColor=SLATE, fontName="Courier")),
                    Paragraph(ar.angle_notes or "",
                              S("an", fontSize=7.5, textColor=SLATE, leading=11))
                ]
                row.append(cell)
            if len(row) == 1:
                row.append(["","","",""])
            story.append(Table([row], colWidths=[87*mm, 87*mm],
                               style=[("VALIGN",(0,0),(-1,-1),"TOP"),
                                      ("TOPPADDING",(0,0),(-1,-1),3),
                                      ("BOTTOMPADDING",(0,0),(-1,-1),5)]))

    story.append(Spacer(1,12))

    # ══ BADGES ════════════════════════════════════════════════════
    ov    = overview
    cond  = ov.get("overall_condition","fair")
    drv   = ov.get("drivability","unknown").replace("_"," ")
    risk  = ov.get("total_loss_risk","medium")
    struct= ov.get("structural_integrity","intact").replace("_"," ")

    story.append(Table([[
        badge(f"Condition: {cond}",
              COND_C.get(cond, ORANGE)),
        badge(f"Drivability: {drv}",
              RED if "undri" in drv or "not_" in drv else
              ORANGE if "caution" in drv else GREEN),
        badge(f"Structure: {struct}",
              RED if "critical" in struct or "compromi" in struct else
              ORANGE if "concern" in struct else GREEN),
        badge(f"Loss Risk: {risk}",
              RED if risk=="high" else ORANGE if risk=="medium" else GREEN),
    ]], colWidths=[W/4]*4,
       style=[("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4)]))
    story.append(Spacer(1,16))

    # ══ VEHICLE OVERVIEW ══════════════════════════════════════════
    story += [Paragraph("Vehicle Overview", sH1), divider()]
    info = Table([
        [Paragraph("Vehicle",          sLabel), Paragraph(ov.get("vehicle","—"), sValue)],
        [Paragraph("Damage Detections",sLabel), Paragraph(str(ov.get("total_damage_areas", len(all_damages))), sValue)],
        [Paragraph("Estimated Repair Cost", sLabel),
         Paragraph(f"{ov.get('total_cost_min_dzd',0):,.0f} – "
                   f"{ov.get('total_cost_max_dzd',0):,.0f} DZD",
                   S("cost", fontSize=12, textColor=NAVY, fontName="Helvetica-Bold"))],
        [Paragraph("Labor Estimate",   sLabel),
         Paragraph(f"{ov.get('labor_hours_total_min',0):.0f} – "
                   f"{ov.get('labor_hours_total_max',0):.0f} hours", sValue)],
        [Paragraph("Recommendation",   sLabel),
         Paragraph(ov.get("recommendation","—").replace("_"," ").title(), sValue)],
        [Paragraph("Hidden Damage Risk", sLabel),
         Paragraph(ov.get("hidden_damage_risk","medium").upper(),
                   S("hd", fontSize=10, fontName="Helvetica-Bold",
                     textColor={"low":GREEN,"medium":ORANGE,"high":RED}.get(
                         ov.get("hidden_damage_risk","medium"), ORANGE)))],
    ], colWidths=[52*mm, 122*mm],
       style=[("ROWBACKGROUNDS",(0,0),(-1,-1),[LIGHT,WHITE]),
              ("TOPPADDING",(0,0),(-1,-1),9),("BOTTOMPADDING",(0,0),(-1,-1),9),
              ("LEFTPADDING",(0,0),(-1,-1),10),
              ("LINEBELOW",(0,0),(-1,-2),.5,BORDER),
              ("BOX",(0,0),(-1,-1),.75,BORDER)])
    story += [info, Spacer(1,16)]

    if ov.get("summary"):
        story += [Paragraph("Assessment Summary", sH1), divider(),
                  Paragraph(ov["summary"], sBody), Spacer(1,10)]

    if ov.get("primary_concerns"):
        story += [Paragraph("Primary Concerns", sH1), divider()]
        for c in ov["primary_concerns"]:
            story.append(Paragraph(f"▸  {c}",
                S("pc", fontSize=9, textColor=SLATE, leading=14, leftIndent=8)))
        story.append(Spacer(1,8))

    if ov.get("assessor_notes"):
        story += [Paragraph("Assessor Notes", sH2),
                  Paragraph(ov["assessor_notes"], sBody)]

    story.append(PageBreak())

    # ══ PER-ANGLE DETAIL PAGES ════════════════════════════════════
    for ar in angle_results:
        lbl = ANGLE_DISPLAY.get(ar.angle, ar.angle.upper())

        hrow = Table([[
            Paragraph(f"{lbl}  —  {ar.damage_count} detection(s)",
                      S("ah", fontSize=11, textColor=WHITE, fontName="Helvetica-Bold")),
            Paragraph(f"Condition: {ar.angle_condition.upper()}",
                      S("ac", fontSize=10, textColor=YELLOW,
                        fontName="Helvetica-Bold", alignment=TA_RIGHT))
        ]], colWidths=[120*mm, 54*mm],
           style=[("BACKGROUND",(0,0),(-1,-1),NAVY),("PADDING",(0,0),(-1,-1),9)])
        story += [hrow, Spacer(1,6)]

        # Detection class tally
        tally_str = "  ·  ".join(f"{k}: {v}" for k, v in sorted(ar.all_probs.items()))
        story.append(Paragraph(tally_str or "no detections", sMono))
        story.append(Spacer(1,6))

        # Full annotated image (all boxes drawn)
        story.append(b64_to_rl(ar.annotated_image_base64, 174, 95))
        if ar.angle_notes:
            story += [Spacer(1,4),
                      Paragraph(ar.angle_notes,
                                S("an2", fontSize=9, textColor=SLATE, leading=12))]
        story.append(Spacer(1,10))

        # ── Per-damage entries with crop thumbnail ────────────────
        for d in ar.damages:
            sc        = SEV_C.get(d.severity_label, ORANGE)
            yolo_col  = YOLO_COLORS.get(d.yolo_class, ACCENT)

            dhdr = Table([[
                Paragraph(f"#{d.index}  {d.car_part.upper()}",
                          S("dh", fontSize=10, textColor=WHITE, fontName="Helvetica-Bold")),
                Paragraph(f"{d.yolo_damage_class}  ·  "
                          f"{d.severity_label.upper()} ({d.severity_score}/10)  ·  "
                          f"PRIORITY: {d.priority.upper()}",
                          S("ds", fontSize=9, textColor=WHITE, alignment=TA_RIGHT))
            ]], colWidths=[80*mm, 94*mm],
               style=[("BACKGROUND",(0,0),(-1,-1),sc),("PADDING",(0,0),(-1,-1),7)])

            # Try to build crop thumbnail from annotated image
            crop_img = _crop_for_pdf(
                ar.annotated_image_base64,
                d.bounding_box,
                d.yolo_class,
            )

            detail_rows = [
                [Paragraph("Description",   sLabel), Paragraph(d.description,  sBody)],
                [Paragraph("Repair Method", sLabel), Paragraph(d.repair_method, sBody)],
                [Paragraph("Complexity",    sLabel),
                 Paragraph(d.repair_complexity.replace("_"," ").title(), sBody)],
                [Paragraph("Affected Area", sLabel), Paragraph(d.affected_area_pct, sBody)],
                [Paragraph("Labor",         sLabel),
                 Paragraph(f"{d.labor_hours_min}–{d.labor_hours_max} hours", sBody)],
                [Paragraph("Cost (DZD)",    sLabel),
                 Paragraph(f"<b>{d.cost_min_dzd:,.0f} – {d.cost_max_dzd:,.0f} DZD</b>",
                           S("ce", fontSize=11, textColor=sc, fontName="Helvetica-Bold"))],
                [Paragraph("YOLO Class",    sLabel),
                 Paragraph(f"{d.yolo_damage_class}  ({d.yolo_class})  "
                           f"conf: {d.confidence:.0%}",
                           S("yc", fontSize=8, textColor=yolo_col, fontName="Courier"))],
                [Paragraph("Bounding Box",  sLabel),
                 Paragraph(
                     f"[{', '.join(f'{v:.3f}' for v in d.bounding_box)}]"
                     if d.bounding_box else "full image",
                     sMono)],
            ]
            if d.safety_risk:
                detail_rows.append([
                    Paragraph("⚠ Safety Risk",
                               S("sr", fontSize=9, textColor=RED, fontName="Helvetica-Bold")),
                    Paragraph("Requires immediate professional inspection",
                               S("srb", fontSize=9, textColor=RED))
                ])
            if d.notes:
                detail_rows.append([Paragraph("Notes", sLabel), Paragraph(d.notes, sBody)])

            dtbl = Table(detail_rows,
                         colWidths=[30*mm, 144*mm],
                         style=[("FONTSIZE",(0,0),(-1,-1),9),
                                ("TOPPADDING",(0,0),(-1,-1),4),
                                ("BOTTOMPADDING",(0,0),(-1,-1),4),
                                ("LINEBELOW",(0,0),(-1,-2),.5,BORDER)])

            # If we have a crop thumbnail, place it beside the detail table
            if crop_img is not None:
                combined = Table([[crop_img, dtbl]],
                                 colWidths=[44*mm, 130*mm],
                                 style=[("VALIGN",(0,0),(-1,-1),"TOP"),
                                        ("LEFTPADDING",(0,0),(0,-1),0),
                                        ("RIGHTPADDING",(0,0),(0,-1),6)])
                story.append(KeepTogether([dhdr, Spacer(1,3), combined, Spacer(1,8)]))
            else:
                story.append(KeepTogether([dhdr, Spacer(1,3), dtbl, Spacer(1,8)]))

        story.append(PageBreak())

    # ══ FINAL COST TABLE ══════════════════════════════════════════
    story += [Paragraph("Complete Repair Cost Breakdown", sH1), divider(1.5, NAVY)]

    def th(t): return Paragraph(t, S("th", fontSize=9, textColor=WHITE,
                                     fontName="Helvetica-Bold", alignment=TA_CENTER))
    rows = [[th("#"), th("Angle"), th("Part"), th("YOLO Class"),
             th("Severity"), th("Hours"), th("Cost (DZD)"), th("Priority")]]
    tmin=0; tmax=0; lmin=0; lmax=0
    for d in all_damages:
        tmin += d.cost_min_dzd; tmax += d.cost_max_dzd
        lmin += d.labor_hours_min; lmax += d.labor_hours_max
        sc  = SEV_C.get(d.severity_label, ORANGE)
        yc  = YOLO_COLORS.get(d.yolo_class, ACCENT)
        rows.append([
            str(d.index),
            ANGLE_DISPLAY.get(d.angle, d.angle)[:8],
            d.car_part[:20],
            Paragraph(d.yolo_damage_class[:14],
                      S("ycc", fontSize=8, textColor=yc,
                        fontName="Helvetica-Bold", alignment=TA_CENTER)),
            Paragraph(f"<b>{d.severity_score}/10</b>",
                      S("s", fontSize=8, textColor=sc,
                        fontName="Helvetica-Bold", alignment=TA_CENTER)),
            f"{d.labor_hours_min:.0f}–{d.labor_hours_max:.0f}h",
            f"{d.cost_min_dzd:,.0f}–{d.cost_max_dzd:,.0f}",
            Paragraph(d.priority.upper(),
                      S("p", fontSize=8, textColor=PRI_C.get(d.priority, ACCENT),
                        fontName="Helvetica-Bold", alignment=TA_CENTER)),
        ])
    rows.append(["","","","",
                 Paragraph("<b>TOTAL</b>",
                           S("tot", fontSize=9, fontName="Helvetica-Bold", alignment=TA_CENTER)),
                 Paragraph(f"<b>{lmin:.0f}–{lmax:.0f}h</b>",
                           S("tl",  fontSize=9, fontName="Helvetica-Bold", alignment=TA_CENTER)),
                 Paragraph(f"<b>{tmin:,.0f}–{tmax:,.0f}</b>",
                           S("tc",  fontSize=9, fontName="Helvetica-Bold", alignment=TA_CENTER)),
                 ""])

    story.append(Table(rows,
        colWidths=[9*mm, 20*mm, 34*mm, 26*mm, 16*mm, 16*mm, 36*mm, 18*mm],
        style=[("BACKGROUND",(0,0),(-1,0),NAVY),
               ("ROWBACKGROUNDS",(0,1),(-1,-2),[WHITE,LIGHT]),
               ("BACKGROUND",(0,-1),(-1,-1),colors.HexColor("#EFF6FF")),
               ("FONTNAME",(0,-1),(-1,-1),"Helvetica-Bold"),
               ("GRID",(0,0),(-1,-1),.5,BORDER),
               ("FONTSIZE",(0,1),(-1,-1),8),
               ("ALIGN",(0,0),(-1,-1),"CENTER"),
               ("VALIGN",(0,0),(-1,-1),"MIDDLE"),
               ("PADDING",(0,0),(-1,-1),5)]))

    story += [Spacer(1,8),
              Paragraph("* All costs are estimates in Algerian Dinar (DZD) based on local market "
                        "rates. Final pricing may vary by region and garage.",
                        S("disc", fontSize=7.5, textColor=SLATE, leading=11))]

    doc.build(story, onFirstPage=footer_fn, onLaterPages=footer_fn)
    return buf.getvalue()