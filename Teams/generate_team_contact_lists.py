#!/mnt/c/dev/postgres-mcp-venv-linux/bin/python

from __future__ import annotations

import csv
import io
import os
import re
import subprocess
import zipfile
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from difflib import SequenceMatcher
from pathlib import Path
from typing import Iterable
from xml.etree import ElementTree as ET

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "generated"
NAME_OVERRIDE_FILE = BASE_DIR / "name_overrides.csv"
DB_DSN = os.environ.get(
    "TEAM_CONTACTS_DSN",
    "postgresql://postgres:6523Tike@192.168.1.248:5432/postgres",
)
SEASON = os.environ.get("TEAM_CONTACTS_SEASON", "2026")

NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
IGNORED_CELL_VALUES = {"", "HALF"}

THEME = {
    "navy": "2F5496",
    "light": "D9E2F3",
    "gold": "C9A227",
    "ink": "1F1F1F",
    "white": "FFFFFF",
    "grey": "6B7280",
}


@dataclass
class ContactCandidate:
    first_name: str
    last_name: str
    member_status: str
    email: str
    phone: str
    mobile: str
    share_contact_detail: str


@dataclass
class MemberCandidate:
    first_name: str
    last_name: str
    category: str
    email: str
    phone: str
    mobile: str


@dataclass
class SignupCandidate:
    first_name: str
    last_name: str
    category: str
    email: str


@dataclass
class JuniorMainContactCandidate:
    first_name: str
    last_name: str
    member_name: str
    main_contact_name: str
    main_contact_email: str
    main_contact_phone: str
    main_contact_mobile: str
    parent_share_contact_detail: str
    match_rule: str


@dataclass
class ReviewEntry:
    section: str
    source_name: str
    target_name: str
    reason: str
    team_name: str

def run_query(sql: str) -> list[dict[str, str]]:
    result = subprocess.run(
        ["psql", DB_DSN, "--csv", "-c", sql],
        check=True,
        capture_output=True,
        text=True,
    )
    return list(csv.DictReader(io.StringIO(result.stdout)))


def normalize_name(value: str) -> str:
    cleaned = " ".join((value or "").replace("\xa0", " ").split())
    cleaned = cleaned.replace("–", "-").replace("—", "-")
    cleaned = re.sub(r"[^A-Za-z0-9]+", "", cleaned)
    return cleaned.casefold()


def load_name_overrides() -> dict[str, set[str]]:
    overrides: dict[str, set[str]] = defaultdict(set)
    if not NAME_OVERRIDE_FILE.exists():
        return overrides
    with NAME_OVERRIDE_FILE.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            source = normalize_name(row.get("source", ""))
            target = normalize_name(row.get("target", ""))
            if source and target:
                overrides[source].add(target)
    return overrides


NAME_OVERRIDES = load_name_overrides()


def clean_name(value: str) -> str:
    value = " ".join((value or "").replace("\xa0", " ").split())
    value = value.replace("–", "-").replace("—", "-")
    value = re.sub(r"\s*[©]\s*$", "", value)
    value = re.sub(r"\s*\(\s*c\s*\)\s*$", "", value, flags=re.I)
    value = re.sub(r"\s+c\s*$", "", value, flags=re.I)
    value = re.sub(r"\s+capt\.?\s*$", "", value, flags=re.I)
    value = re.sub(r"[.,;:]+$", "", value)
    return " ".join(value.split())


def is_captain(value: str) -> bool:
    value = value or ""
    return bool(
        re.search(r"(©|\(\s*c\s*\)|\bc\b|\bcapt\.?\b)\s*$", value.strip(), flags=re.I)
    )


def clean_phone(value: str) -> str:
    value = (value or "").strip()
    value = value.strip("[]")
    value = re.sub(r"\s+", " ", value)
    return value


def truthy_share_contact_detail(value: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", "", (value or "").casefold())
    return normalized in {"yes", "y", "true", "1"}


def normalize_email_local(value: str) -> str:
    local = (value or "").split("@", 1)[0]
    return re.sub(r"[^a-z0-9]+", "", local.casefold())


def first_name_key(value: str) -> str:
    parts = value.split()
    return parts[0].casefold() if parts else ""


def split_person_name(value: str) -> tuple[str, str]:
    parts = value.split()
    if len(parts) <= 1:
        return value, ""
    return parts[0], " ".join(parts[1:])


def candidate_key(candidate: object) -> str:
    return normalize_name(f"{candidate.first_name} {candidate.last_name}")


def candidate_full_name(candidate: object) -> str:
    return f"{candidate.first_name} {candidate.last_name}".strip()


def choose_display_name(existing: str, new: str) -> str:
    if not existing:
        return new
    if existing.isupper() and not new.isupper():
        return new
    return existing


def doc_title_from_filename(path: Path) -> str:
    title = path.stem.replace("SUMMER", "Summer")
    title = title.replace("SQUADS", "Squads")
    title = re.sub(r"\s+", " ", title)
    return title.strip()


def sheet_title(header: str) -> str:
    words = [w.capitalize() for w in header.split()]
    value = " ".join(words)
    return value[:31]


def split_cell_entries(paragraphs: Iterable[str]) -> list[str]:
    raw_entries: list[str] = []
    for paragraph in paragraphs:
        parts = re.split(r"\.\s+(?=[A-Z])", paragraph.strip())
        for part in parts:
            cleaned = part.strip(" .")
            if cleaned:
                raw_entries.append(cleaned)

    entries: list[str] = []
    single_word_buffer: list[str] = []
    for entry in raw_entries:
        if len(entry.split()) == 1:
            single_word_buffer.append(entry)
            continue
        if single_word_buffer:
            entries.append(" ".join(single_word_buffer))
            single_word_buffer = []
        entries.append(entry)

    if single_word_buffer:
        entries.append(" ".join(single_word_buffer))

    return entries


def parse_docx_teams(path: Path) -> dict[str, list[dict[str, object]]]:
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))

    table = root.find(".//w:tbl", NS)
    if table is None:
        raise RuntimeError(f"No table found in {path.name}")

    row_cells: list[list[list[str]]] = []
    for tr in table.findall("./w:tr", NS):
        row: list[list[str]] = []
        for tc in tr.findall("./w:tc", NS):
            paragraphs: list[str] = []
            for p in tc.findall("./w:p", NS):
                text = "".join((t.text or "") for t in p.findall(".//w:t", NS))
                text = " ".join(text.replace("\xa0", " ").split())
                if text:
                    paragraphs.append(text)
            row.append(paragraphs)
        row_cells.append(row)

    if not row_cells:
        return {}

    headers = [" ".join(cell).strip() for cell in row_cells[0][1:]]
    teams: dict[str, list[dict[str, object]]] = {header: [] for header in headers if header}

    for row in row_cells[1:]:
        for index, header in enumerate(headers, start=1):
            if not header or index >= len(row):
                continue
            for paragraph_text in split_cell_entries(row[index]):
                cleaned = clean_name(paragraph_text)
                if cleaned in IGNORED_CELL_VALUES:
                    continue
                teams[header].append(
                    {
                        "name": cleaned,
                        "captain": is_captain(paragraph_text),
                    }
                )
    return teams


def load_lookup_data() -> tuple[
    dict[str, list[MemberCandidate]],
    dict[str, list[ContactCandidate]],
    dict[str, list[SignupCandidate]],
    dict[str, list[JuniorMainContactCandidate]],
]:
    members_sql = f"""
        select
          trim(m."First name") as first_name,
          trim(m."Last name") as last_name,
          mp.category as category,
          coalesce(nullif(trim(m."Email address"), ''), '') as email_address,
          coalesce(nullif(trim(m."Phone number"), ''), '') as phone_number,
          coalesce(nullif(trim(m."Mobile number"), ''), '') as mobile_number
        from public.raw_members m
        join public.membership_packages mp
          on mp.name = m."Membership"
        where coalesce(m.is_current, true) = true
          and mp.season = '{SEASON}'
          and coalesce(m."Status", '') = 'Active'
          and coalesce(m."Payment", '') in ('Paid', 'Part Paid')
          and mp.category not in ('Social', 'Pavilion Key')
        order by 1, 2;
    """
    contacts_sql = """
        select
          c.first_name,
          c.last_name,
          coalesce(c.member_status, '') as member_status,
          c.norm_name,
          coalesce(c.email_address, '') as email_address,
          coalesce(c.phone_number, '') as phone_number,
          coalesce(c.mobile_number, '') as mobile_number,
          coalesce(nullif(trim(rc."Share Contact Detail"), ''), '') as share_contact_detail
        from public.vw_best_current_contacts c
        left join public.raw_contacts rc
          on rc.id = c.contact_id
        order by norm_name, contact_id;
    """
    signups_sql = f"""
        select
          trim(coalesce(ms."First name", split_part(ms.member, ' ', 1))) as first_name,
          trim(coalesce(ms."Last name", regexp_replace(ms.member, '^[^ ]+\\s*', ''))) as last_name,
          mp.category as category,
          coalesce(nullif(trim(ms.email_address), ''), '') as email_address
        from public.member_signups ms
        join public.membership_packages mp
          on mp.name = ms.product
        where mp.season = '{SEASON}'
          and coalesce(ms.status, '') = 'Complete'
          and mp.category not in ('Social', 'Pavilion Key')
        order by 1, 2;
    """
    junior_main_contacts_sql = """
        select
          member_name,
          main_contact_name,
          coalesce(main_contact_email, '') as main_contact_email,
          coalesce(main_contact_phone, '') as main_contact_phone,
          coalesce(main_contact_mobile, '') as main_contact_mobile,
          coalesce(nullif(trim(rc."Share Contact Detail"), ''), '') as parent_share_contact_detail,
          match_rule
        from public.vw_junior_main_contacts
        left join public.raw_contacts rc
          on rc.id = resolved_contact_id
        where match_confidence = 'high'
        order by member_name;
    """

    members_by_name: dict[str, list[MemberCandidate]] = defaultdict(list)
    contacts_by_name: dict[str, list[ContactCandidate]] = defaultdict(list)
    signups_by_name: dict[str, list[SignupCandidate]] = defaultdict(list)
    junior_main_contacts_by_name: dict[str, list[JuniorMainContactCandidate]] = defaultdict(list)

    for row in run_query(members_sql):
        members_by_name[normalize_name(f'{row["first_name"]} {row["last_name"]}')].append(
            MemberCandidate(
                first_name=row["first_name"],
                last_name=row["last_name"],
                category=row["category"],
                email=row["email_address"],
                phone=clean_phone(row["phone_number"]),
                mobile=clean_phone(row["mobile_number"]),
            )
        )

    for row in run_query(contacts_sql):
        contacts_by_name[normalize_name(f'{row["first_name"]} {row["last_name"]}')].append(
            ContactCandidate(
                first_name=row["first_name"],
                last_name=row["last_name"],
                member_status=row["member_status"],
                email=row["email_address"],
                phone=clean_phone(row["phone_number"]),
                mobile=clean_phone(row["mobile_number"]),
                share_contact_detail=row["share_contact_detail"],
            )
        )

    for row in run_query(signups_sql):
        signups_by_name[normalize_name(f'{row["first_name"]} {row["last_name"]}')].append(
            SignupCandidate(
                first_name=row["first_name"],
                last_name=row["last_name"],
                category=row["category"],
                email=row["email_address"],
            )
        )

    for row in run_query(junior_main_contacts_sql):
        first_name, last_name = split_person_name(row["member_name"])
        junior_main_contacts_by_name[normalize_name(row["member_name"])].append(
            JuniorMainContactCandidate(
                first_name=first_name,
                last_name=last_name,
                member_name=row["member_name"],
                main_contact_name=row["main_contact_name"],
                main_contact_email=row["main_contact_email"],
                main_contact_phone=clean_phone(row["main_contact_phone"]),
                main_contact_mobile=clean_phone(row["main_contact_mobile"]),
                parent_share_contact_detail=row["parent_share_contact_detail"],
                match_rule=row["match_rule"],
            )
        )

    return members_by_name, contacts_by_name, signups_by_name, junior_main_contacts_by_name


def choose_contact_detail(
    member_candidates: list[MemberCandidate],
    contact_candidates: list[ContactCandidate],
    signup_candidates: list[SignupCandidate],
    junior_main_contact_candidates: list[JuniorMainContactCandidate],
) -> tuple[str, str, bool]:
    phone = ""
    email = ""
    self_contact = contact_candidates[0] if len(contact_candidates) == 1 else None
    main_contact = junior_main_contact_candidates[0] if len(junior_main_contact_candidates) == 1 else None
    has_self_consent = self_contact is not None and truthy_share_contact_detail(
        self_contact.share_contact_detail
    )
    has_parent_consent = main_contact is not None and truthy_share_contact_detail(
        main_contact.parent_share_contact_detail
    )

    self_phone = (self_contact.mobile or self_contact.phone) if self_contact and has_self_consent else ""
    self_email = self_contact.email if self_contact and has_self_consent else ""
    parent_phone = (
        main_contact.main_contact_mobile or main_contact.main_contact_phone
        if main_contact and has_parent_consent
        else ""
    )
    parent_email = main_contact.main_contact_email if main_contact and has_parent_consent else ""

    if self_phone and self_email and parent_phone and parent_email:
        return (
            f"Self: {self_phone}\nParent: {parent_phone}",
            f"Self: {self_email}\nParent: {parent_email}",
            False,
        )

    phone = parent_phone or self_phone
    email = parent_email or self_email

    if not phone and not email and (
        (self_contact is not None and not has_self_consent)
        or (main_contact is not None and not has_parent_consent)
    ):
        return "No Consent", "No Consent", True

    if len(member_candidates) == 1:
        member = member_candidates[0]
        if self_contact is None or has_self_consent:
            phone = phone or member.mobile or member.phone
            email = email or member.email

    if self_contact is not None and has_self_consent:
        phone = phone or self_phone
        email = email or self_email

    if len(signup_candidates) == 1:
        signup = signup_candidates[0]
        if self_contact is None or has_self_consent:
            email = email or signup.email

    return phone, email, False


def email_matches_name(candidate: ContactCandidate, source_name: str) -> bool:
    first_name, last_name = split_person_name(source_name)
    norm_first = normalize_name(first_name)
    norm_last = normalize_name(last_name)
    local = normalize_email_local(candidate.email)
    if not norm_first or not norm_last or not local:
        return False
    return norm_first in local and norm_last in local


def contact_quality_score(candidate: ContactCandidate) -> tuple[int, int, int]:
    return (
        1 if candidate.email else 0,
        1 if candidate.mobile else 0,
        1 if candidate.phone else 0,
    )


def unique_best_contact(candidates: list[ContactCandidate]) -> list[ContactCandidate]:
    if len(candidates) <= 1:
        return candidates
    ranked = sorted(candidates, key=contact_quality_score, reverse=True)
    best = contact_quality_score(ranked[0])
    second = contact_quality_score(ranked[1])
    if best > second:
        return [ranked[0]]
    return candidates


def disambiguate_contact_candidates(
    contact_candidates: list[ContactCandidate],
    source_name: str,
) -> tuple[list[ContactCandidate], bool]:
    if len(contact_candidates) <= 1:
        return contact_candidates, False

    active = [candidate for candidate in contact_candidates if candidate.member_status == "Active Member"]
    if len(active) == 1:
        return active, True
    best_active = unique_best_contact(active)
    if len(best_active) == 1:
        return best_active, True

    matching_active = [candidate for candidate in active if email_matches_name(candidate, source_name)]
    if len(matching_active) == 1:
        return matching_active, True

    non_lapsed = [
        candidate
        for candidate in contact_candidates
        if candidate.member_status not in {"Lapsed Member", "Non Member", ""}
    ]
    if len(non_lapsed) == 1:
        return non_lapsed, True
    best_non_lapsed = unique_best_contact(non_lapsed)
    if len(best_non_lapsed) == 1:
        return best_non_lapsed, True

    matching_non_lapsed = [
        candidate for candidate in non_lapsed if email_matches_name(candidate, source_name)
    ]
    if len(matching_non_lapsed) == 1:
        return matching_non_lapsed, True

    matching_all = [candidate for candidate in contact_candidates if email_matches_name(candidate, source_name)]
    if len(matching_all) == 1:
        return matching_all, True

    return contact_candidates, False


def nickname_variants(first_name: str) -> set[str]:
    norm_first = normalize_name(first_name)
    variants = {norm_first}
    if norm_first in NAME_OVERRIDES:
        variants |= NAME_OVERRIDES[norm_first]
    return variants


def unique_nickname_candidates(name: str, by_name: dict[str, list[object]]) -> list[object]:
    first_name, last_name = split_person_name(name)
    norm_last = normalize_name(last_name)
    if not norm_last:
        return []
    keys = []
    for variant in nickname_variants(first_name):
        candidate_key = normalize_name(f"{variant} {norm_last}")
        if candidate_key in by_name:
            keys.append(candidate_key)
    keys = sorted(set(keys))
    if len(keys) != 1:
        return []
    candidates = by_name[keys[0]]
    return candidates if len(candidates) == 1 else []


def fuzzy_score_parts(source: str, target: str) -> float:
    return SequenceMatcher(None, normalize_name(source), normalize_name(target)).ratio()


def unique_fuzzy_candidates(name: str, by_name: dict[str, list[object]]) -> list[object]:
    first_name, last_name = split_person_name(name)
    norm_first = normalize_name(first_name)
    norm_last = normalize_name(last_name)
    if not norm_first or not norm_last:
        return []

    matches: list[tuple[float, str, list[object]]] = []
    for key, candidates in by_name.items():
        if len(candidates) != 1:
            continue
        candidate = candidates[0]
        cand_first = normalize_name(candidate.first_name)
        cand_last = normalize_name(candidate.last_name)
        if not cand_first or not cand_last:
            continue
        if cand_first[:1] != norm_first[:1] or cand_last[:1] != norm_last[:1]:
            continue
        first_score = fuzzy_score_parts(first_name, candidate.first_name)
        last_score = fuzzy_score_parts(last_name, candidate.last_name)
        full_score = fuzzy_score_parts(
            f"{first_name} {last_name}",
            f"{candidate.first_name} {candidate.last_name}",
        )
        if first_score >= 0.72 and last_score >= 0.80 and full_score >= 0.84:
            matches.append((full_score + last_score + first_score, key, candidates))

    if not matches:
        return []

    matches.sort(key=lambda item: item[0], reverse=True)
    best_score, best_key, best_candidates = matches[0]
    if len(matches) > 1 and abs(best_score - matches[1][0]) < 0.08:
        return []
    return best_candidates


def resolve_row(
    name: str,
    members_by_name: dict[str, list[MemberCandidate]],
    contacts_by_name: dict[str, list[ContactCandidate]],
    signups_by_name: dict[str, list[SignupCandidate]],
    junior_main_contacts_by_name: dict[str, list[JuniorMainContactCandidate]],
) -> dict[str, str]:
    norm_name = normalize_name(name)
    override_name = next(iter(NAME_OVERRIDES.get(norm_name, set())), "")
    override_applied = bool(override_name)
    if override_name:
        norm_name = override_name
    member_candidates = members_by_name.get(norm_name, [])
    contact_candidates, best_fit_applied = disambiguate_contact_candidates(contacts_by_name.get(norm_name, []), name)
    signup_candidates = signups_by_name.get(norm_name, [])
    junior_main_contact_candidates = junior_main_contacts_by_name.get(norm_name, [])

    phone, email, consent_denied = choose_contact_detail(
        member_candidates,
        contact_candidates,
        signup_candidates,
        junior_main_contact_candidates,
    )

    if len(member_candidates) == 1:
        return {
            "category": member_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Override" if override_applied else "",
            "review_section": "explicit_override" if override_applied else "",
            "review_target": candidate_full_name(member_candidates[0]) if override_applied else "",
            "review_reason": "explicit full-name override from name_overrides.csv" if override_applied else "",
            "no_consent": consent_denied,
        }

    if len(member_candidates) > 1:
        return {"category": "No Match", "phone": "", "email": "", "match_note": "", "no_consent": False}

    if len(signup_candidates) == 1:
        return {
            "category": signup_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Override" if override_applied else "",
            "review_section": "explicit_override" if override_applied else "",
            "review_target": candidate_full_name(signup_candidates[0]) if override_applied else "",
            "review_reason": "explicit full-name override from name_overrides.csv" if override_applied else "",
            "no_consent": consent_denied,
        }

    if len(signup_candidates) > 1:
        return {"category": "No Match", "phone": "", "email": "", "match_note": "", "no_consent": False}

    if len(contact_candidates) == 1:
        return {
            "category": "Not Signed Up",
            "phone": phone,
            "email": email,
            "match_note": "Override" if override_applied else ("Best Fit" if best_fit_applied else ""),
            "review_section": "explicit_override" if override_applied else "",
            "review_target": candidate_full_name(contact_candidates[0]) if override_applied else "",
            "review_reason": "explicit full-name override from name_overrides.csv" if override_applied else "",
            "no_consent": consent_denied,
        }

    member_candidates = unique_nickname_candidates(name, members_by_name)
    contact_candidates, best_fit_applied = disambiguate_contact_candidates(
        unique_nickname_candidates(name, contacts_by_name),
        name,
    )
    signup_candidates = unique_nickname_candidates(name, signups_by_name)
    junior_main_contact_candidates = unique_nickname_candidates(name, junior_main_contacts_by_name)
    phone, email, consent_denied = choose_contact_detail(
        member_candidates,
        contact_candidates,
        signup_candidates,
        junior_main_contact_candidates,
    )

    if len(member_candidates) == 1:
        return {
            "category": member_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Nickname",
            "review_section": "nickname",
            "review_target": candidate_full_name(member_candidates[0]),
            "review_reason": "first-name override",
            "no_consent": consent_denied,
        }

    if len(signup_candidates) == 1:
        return {
            "category": signup_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Nickname",
            "review_section": "nickname",
            "review_target": candidate_full_name(signup_candidates[0]),
            "review_reason": "first-name override",
            "no_consent": consent_denied,
        }

    if len(contact_candidates) == 1:
        return {
            "category": "Not Signed Up",
            "phone": phone,
            "email": email,
            "match_note": "Best Fit" if best_fit_applied else "Nickname",
            "review_section": "nickname",
            "review_target": candidate_full_name(contact_candidates[0]),
            "review_reason": "first-name override",
            "no_consent": consent_denied,
        }

    member_candidates = unique_fuzzy_candidates(name, members_by_name)
    contact_candidates, best_fit_applied = disambiguate_contact_candidates(
        unique_fuzzy_candidates(name, contacts_by_name),
        name,
    )
    signup_candidates = unique_fuzzy_candidates(name, signups_by_name)
    junior_main_contact_candidates = unique_fuzzy_candidates(name, junior_main_contacts_by_name)
    phone, email, consent_denied = choose_contact_detail(
        member_candidates,
        contact_candidates,
        signup_candidates,
        junior_main_contact_candidates,
    )

    if len(member_candidates) == 1:
        return {
            "category": member_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Fuzzy",
            "review_section": "fuzzy",
            "review_target": candidate_full_name(member_candidates[0]),
            "review_reason": "fuzzy name match",
            "no_consent": consent_denied,
        }

    if len(signup_candidates) == 1:
        return {
            "category": signup_candidates[0].category,
            "phone": phone,
            "email": email,
            "match_note": "Fuzzy",
            "review_section": "fuzzy",
            "review_target": candidate_full_name(signup_candidates[0]),
            "review_reason": "fuzzy name match",
            "no_consent": consent_denied,
        }

    if len(contact_candidates) == 1:
        return {
            "category": "Not Signed Up",
            "phone": phone,
            "email": email,
            "match_note": "Best Fit" if best_fit_applied else "Fuzzy",
            "review_section": "fuzzy",
            "review_target": candidate_full_name(contact_candidates[0]),
            "review_reason": "fuzzy name match",
            "no_consent": consent_denied,
        }

    return {
        "category": "No Match",
        "phone": "",
        "email": "",
        "match_note": "",
        "review_section": "no_match",
        "review_target": "",
        "review_reason": "no unique candidate",
        "no_consent": False,
    }


def build_team_rows(
    teams: dict[str, list[dict[str, object]]],
    members_by_name: dict[str, list[MemberCandidate]],
    contacts_by_name: dict[str, list[ContactCandidate]],
    signups_by_name: dict[str, list[SignupCandidate]],
    junior_main_contacts_by_name: dict[str, list[JuniorMainContactCandidate]],
) -> tuple[dict[str, list[dict[str, str]]], list[ReviewEntry]]:
    resolved: dict[str, list[dict[str, str]]] = {}
    review_entries: list[ReviewEntry] = []

    for team_name, entries in teams.items():
        rows = []
        for entry in entries:
            details = resolve_row(
                entry["name"],
                members_by_name,
                contacts_by_name,
                signups_by_name,
                junior_main_contacts_by_name,
            )
            rows.append(
                {
                    "captain": "C" if entry["captain"] else "",
                    "name": str(entry["name"]),
                    "match_note": details["match_note"],
                    "category": details["category"],
                    "phone": details["phone"],
                    "email": details["email"],
                }
            )
            if details.get("review_section"):
                review_entries.append(
                    ReviewEntry(
                        section=details["review_section"],
                        source_name=str(entry["name"]),
                        target_name=details.get("review_target", ""),
                        reason=details.get("review_reason", ""),
                        team_name=team_name.title(),
                    )
                )
            if details.get("no_consent"):
                review_entries.append(
                    ReviewEntry(
                        section="no_consent",
                        source_name=str(entry["name"]),
                        target_name="",
                        reason="share contact detail not granted",
                        team_name=team_name.title(),
                    )
                )

        rows.sort(key=lambda row: (0 if row["captain"] else 1, first_name_key(row["name"]), row["name"].casefold()))
        resolved[team_name] = rows
    return resolved, review_entries


def group_review_entries(review_entries: list[ReviewEntry]) -> dict[str, list[dict[str, object]]]:
    grouped: dict[tuple[str, str], dict[str, object]] = {}
    for entry in review_entries:
        key = (entry.section, normalize_name(entry.source_name))
        if key not in grouped:
            grouped[key] = {
                "display_name": entry.source_name,
                "target_name": entry.target_name,
                "reason": entry.reason,
                "teams": set(),
            }
        grouped[key]["display_name"] = choose_display_name(grouped[key]["display_name"], entry.source_name)
        grouped[key]["teams"].add(entry.team_name)
        if entry.target_name:
            grouped[key]["target_name"] = entry.target_name

    ordered_sections = ["no_match", "no_consent", "explicit_override", "nickname", "fuzzy"]
    result: dict[str, list[dict[str, object]]] = {section: [] for section in ordered_sections}
    for (section, _), value in grouped.items():
        result[section].append(value)
    for section in ordered_sections:
        result[section].sort(key=lambda item: normalize_name(item["display_name"]))
    return result


def review_markdown_text(review_groups: dict[str, list[dict[str, object]]]) -> str:
    lines = [
        "# Team Match Review",
        "",
        "This file records the current non-trivial name matching used by [generate_team_contact_lists.py](./generate_team_contact_lists.py).",
        "",
        "## Remaining No Match Names",
        "",
    ]
    for item in review_groups["no_match"]:
        teams = ", ".join(sorted(item["teams"]))
        lines.append(f"- `{item['display_name']}` - {item['reason']}. Teams: {teams}")

    lines.extend(["", "## No Consent Contact Details", ""])
    for item in review_groups["no_consent"]:
        teams = ", ".join(sorted(item["teams"]))
        lines.append(f"- `{item['display_name']}` - {item['reason']}. Teams: {teams}")

    lines.extend(["", "## Explicit Full-Name Overrides", ""])
    for item in review_groups["explicit_override"]:
        teams = ", ".join(sorted(item["teams"]))
        lines.append(
            f"- `{item['display_name']}` -> `{item['target_name']}` - {item['reason']}. Teams: {teams}"
        )

    lines.extend(["", "## Short-Name / Nickname Matches", ""])
    for item in review_groups["nickname"]:
        teams = ", ".join(sorted(item["teams"]))
        lines.append(
            f"- `{item['display_name']}` -> `{item['target_name']}` - {item['reason']}. Teams: {teams}"
        )

    lines.extend(["", "## Fuzzy Matches", ""])
    for item in review_groups["fuzzy"]:
        teams = ", ".join(sorted(item["teams"]))
        lines.append(
            f"- `{item['display_name']}` -> `{item['target_name']}` - {item['reason']}. Teams: {teams}"
        )

    lines.append("")
    return "\n".join(lines)


def write_review_markdown(review_groups: dict[str, list[dict[str, object]]], output_path: Path) -> None:
    output_path.write_text(review_markdown_text(review_groups), encoding="utf-8")


def write_review_pdf(review_groups: dict[str, list[dict[str, object]]], output_path: Path) -> None:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "ReviewTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=16,
        textColor=colors.HexColor(f"#{THEME['navy']}"),
        spaceAfter=8,
    )
    section_style = ParagraphStyle(
        "ReviewSection",
        parent=styles["Heading2"],
        fontName="Helvetica-Bold",
        fontSize=12,
        textColor=colors.HexColor(f"#{THEME['gold']}"),
        spaceBefore=8,
        spaceAfter=4,
    )
    body_style = ParagraphStyle(
        "ReviewBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        textColor=colors.HexColor(f"#{THEME['ink']}"),
        leading=13,
        spaceAfter=3,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        leftMargin=15 * mm,
        rightMargin=15 * mm,
        topMargin=15 * mm,
        bottomMargin=15 * mm,
    )

    story = [
        Paragraph("Avondale Tennis Club | Team Match Review", title_style),
        Paragraph(f"Generated {datetime.now().strftime('%d %b %Y %H:%M')}", body_style),
    ]

    section_map = [
        ("Remaining No Match Names", "no_match"),
        ("No Consent Contact Details", "no_consent"),
        ("Explicit Full-Name Overrides", "explicit_override"),
        ("Short-Name / Nickname Matches", "nickname"),
        ("Fuzzy Matches", "fuzzy"),
    ]
    for title, key in section_map:
        story.append(Spacer(1, 2 * mm))
        story.append(Paragraph(title, section_style))
        for item in review_groups[key]:
            teams = ", ".join(sorted(item["teams"]))
            if item["target_name"]:
                text = f"<b>{item['display_name']}</b> -> <b>{item['target_name']}</b> - {item['reason']}. Teams: {teams}"
            else:
                text = f"<b>{item['display_name']}</b> - {item['reason']}. Teams: {teams}"
            story.append(Paragraph(text, body_style))

    doc.build(story)


def write_workbook(title: str, teams: dict[str, list[dict[str, str]]], output_path: Path) -> None:
    workbook = Workbook()
    workbook.remove(workbook.active)

    title_fill = PatternFill("solid", fgColor=THEME["navy"])
    header_fill = PatternFill("solid", fgColor=THEME["light"])
    gold_fill = PatternFill("solid", fgColor=THEME["gold"])
    white_font = Font(color=THEME["white"], bold=True, size=14)
    header_font = Font(color=THEME["ink"], bold=True)
    bold_font = Font(color=THEME["ink"], bold=True)
    body_font = Font(color=THEME["ink"])
    footnote_font = Font(color=THEME["grey"], italic=True, size=10)
    thin = Side(style="thin", color="D0D7DE")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)

    for team_name, rows in teams.items():
        ws = workbook.create_sheet(sheet_title(team_name))
        ws.sheet_view.showGridLines = False
        ws.freeze_panes = "A4"
        ws.merge_cells("A1:F1")
        ws["A1"] = f"Avondale Tennis Club | {title} | {team_name.title()}"
        ws["A1"].fill = title_fill
        ws["A1"].font = white_font
        ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
        ws.row_dimensions[1].height = 24

        ws.merge_cells("A2:F2")
        ws["A2"] = f"Generated {datetime.now().strftime('%d %b %Y %H:%M')}"
        ws["A2"].fill = gold_fill
        ws["A2"].font = Font(color=THEME["ink"], bold=True)
        ws["A2"].alignment = Alignment(horizontal="center")

        headers = ["Captain", "Name", "Match", "Category", "Phone", "Email"]
        for col_index, header in enumerate(headers, start=1):
            cell = ws.cell(row=3, column=col_index, value=header)
            cell.fill = header_fill
            cell.font = header_font
            cell.border = border
            cell.alignment = Alignment(horizontal="center")

        row_index = 4
        for item in rows:
            values = [item["captain"], item["name"], item["match_note"], item["category"], item["phone"], item["email"]]
            for col_index, value in enumerate(values, start=1):
                cell = ws.cell(row=row_index, column=col_index, value=value)
                cell.border = border
                cell.alignment = Alignment(vertical="top", wrap_text=True)
                cell.font = bold_font if item["captain"] == "C" else body_font
            row_index += 1

        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="* Not Signed Up = exact or resolved name matched in club records, but no current paid 2026 membership was found.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="** No Match = no unique exact-name match was found in current club member/contact records.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="*** Best Fit = one row was chosen from several exact-name candidates using the best available contact evidence.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="**** Override = resolved by an explicit override; this usually represents a typo or misspelling in the source data.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="***** Nickname = resolved by a short-name or nickname rule; this may also represent a typo or misspelling in the source data.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="****** Fuzzy = resolved by the cautious fuzzy fallback; this represents a typo or misspelling in the source data.").font = footnote_font
        row_index += 1
        ws.merge_cells(start_row=row_index, start_column=1, end_row=row_index, end_column=6)
        ws.cell(row=row_index, column=1, value="******* No Consent = the current contact record does not allow contact details to be shared, so phone and email are withheld.").font = footnote_font

        widths = {"A": 10, "B": 28, "C": 12, "D": 18, "E": 18, "F": 34}
        for column, width in widths.items():
            ws.column_dimensions[column].width = width

    output_path.parent.mkdir(parents=True, exist_ok=True)
    workbook.save(output_path)


def write_csvs(teams: dict[str, list[dict[str, str]]], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for team_name, rows in teams.items():
        slug = re.sub(r"[^a-z0-9]+", "-", team_name.casefold()).strip("-")
        csv_path = output_dir / f"{slug}.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(["Captain", "Name", "Match", "Category", "Phone", "Email"])
            for row in rows:
                writer.writerow([row["captain"], row["name"], row["match_note"], row["category"], row["phone"], row["email"]])
            writer.writerow([])
            writer.writerow(["* Not Signed Up = exact or resolved name matched in club records, but no current paid 2026 membership was found."])
            writer.writerow(["** No Match = no unique exact-name match was found in current club member/contact records."])
            writer.writerow(["*** Best Fit = one row was chosen from several exact-name candidates using the best available contact evidence."])
            writer.writerow(["**** Override = resolved by an explicit override; this usually represents a typo or misspelling in the source data."])
            writer.writerow(["***** Nickname = resolved by a short-name or nickname rule; this may also represent a typo or misspelling in the source data."])
            writer.writerow(["****** Fuzzy = resolved by the cautious fuzzy fallback; this represents a typo or misspelling in the source data."])
            writer.writerow(["******* No Consent = the current contact record does not allow contact details to be shared, so phone and email are withheld."])


def write_captain_email_list(all_teams: dict[str, dict[str, list[dict[str, str]]]], output_path: Path) -> None:
    emails: list[str] = []
    seen: set[str] = set()

    for teams in all_teams.values():
        for rows in teams.values():
            for row in rows:
                if row["captain"] != "C":
                    continue
                raw_email = row["email"].strip()
                if not raw_email:
                    continue
                for part in raw_email.splitlines():
                    email = re.sub(r"^(Self|Parent):\s*", "", part).strip()
                    if not email or email.casefold() == "no consent":
                        continue
                    key = email.casefold()
                    if key in seen:
                        continue
                    seen.add(key)
                    emails.append(email)

    output_path.write_text(", ".join(emails) + ("\n" if emails else ""), encoding="utf-8")


def team_slug(team_name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", team_name.casefold()).strip("-")


def write_pdf(title: str, teams: dict[str, list[dict[str, str]]], output_path: Path) -> None:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "AvondaleTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=16,
        textColor=colors.HexColor(f"#{THEME['navy']}"),
        spaceAfter=8,
    )
    subtitle_style = ParagraphStyle(
        "AvondaleSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        textColor=colors.HexColor(f"#{THEME['gold']}"),
        spaceAfter=10,
    )
    note_style = ParagraphStyle(
        "AvondaleNote",
        parent=styles["Normal"],
        fontSize=9,
        textColor=colors.HexColor(f"#{THEME['grey']}"),
        leading=11,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=landscape(A4),
        leftMargin=12 * mm,
        rightMargin=12 * mm,
        topMargin=12 * mm,
        bottomMargin=12 * mm,
    )

    story = []
    team_names = list(teams.keys())
    for index, team_name in enumerate(team_names):
        rows = teams[team_name]
        story.append(Paragraph(f"Avondale Tennis Club | {title} | {team_name.title()}", title_style))
        story.append(Paragraph(f"Generated {datetime.now().strftime('%d %b %Y %H:%M')}", subtitle_style))

        table_data = [["Captain", "Name", "Match", "Category", "Phone", "Email"]]
        for row in rows:
            table_data.append([row["captain"], row["name"], row["match_note"], row["category"], row["phone"], row["email"]])

        table = Table(table_data, colWidths=[18 * mm, 52 * mm, 18 * mm, 30 * mm, 34 * mm, 66 * mm], repeatRows=1)
        style_commands = [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(f"#{THEME['navy']}")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTNAME", (0, 1), (-1, -1), "Helvetica"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D0D7DE")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#FFFFFF"), colors.HexColor(f"#{THEME['light']}")]),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("ALIGN", (0, 0), (0, -1), "CENTER"),
        ]
        for row_number, row in enumerate(rows, start=1):
            if row["captain"] == "C":
                style_commands.append(("FONTNAME", (0, row_number), (-1, row_number), "Helvetica-Bold"))
        table.setStyle(TableStyle(style_commands))
        story.append(table)
        story.append(Spacer(1, 6 * mm))
        story.append(Paragraph("* Not Signed Up = exact or resolved name matched in club records, but no current paid 2026 membership was found.", note_style))
        story.append(Paragraph("** No Match = no unique exact-name match was found in current club member/contact records.", note_style))
        story.append(Paragraph("*** Best Fit = one row was chosen from several exact-name candidates using the best available contact evidence.", note_style))
        story.append(Paragraph("**** Override = resolved by an explicit override; this usually represents a typo or misspelling in the source data.", note_style))
        story.append(Paragraph("***** Nickname = resolved by a short-name or nickname rule; this may also represent a typo or misspelling in the source data.", note_style))
        story.append(Paragraph("****** Fuzzy = resolved by the cautious fuzzy fallback; this represents a typo or misspelling in the source data.", note_style))
        story.append(Paragraph("******* No Consent = the current contact record does not allow contact details to be shared, so phone and email are withheld.", note_style))

        if index < len(team_names) - 1:
            story.append(PageBreak())

    doc.build(story)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    members_by_name, contacts_by_name, signups_by_name, junior_main_contacts_by_name = load_lookup_data()
    all_review_entries: list[ReviewEntry] = []
    all_resolved_teams: dict[str, dict[str, list[dict[str, str]]]] = {}

    for docx_path in sorted(BASE_DIR.glob("*.docx")):
        title = doc_title_from_filename(docx_path)
        teams = parse_docx_teams(docx_path)
        resolved_teams, review_entries = build_team_rows(
            teams,
            members_by_name,
            contacts_by_name,
            signups_by_name,
            junior_main_contacts_by_name,
        )
        all_review_entries.extend(review_entries)
        all_resolved_teams[docx_path.stem] = resolved_teams

        workbook_path = OUTPUT_DIR / f"{docx_path.stem} - Contact Lists.xlsx"
        csv_dir = OUTPUT_DIR / f"{docx_path.stem} - CSV"
        old_pdf_path = OUTPUT_DIR / f"{docx_path.stem} - Contact Lists.pdf"

        write_workbook(title, resolved_teams, workbook_path)
        write_csvs(resolved_teams, csv_dir)
        for team_name, rows in resolved_teams.items():
            write_pdf(
                title,
                {team_name: rows},
                OUTPUT_DIR / f"{docx_path.stem} - {team_slug(team_name)}.pdf",
            )
        old_pdf_path.unlink(missing_ok=True)

        no_match_count = sum(1 for rows in resolved_teams.values() for row in rows if row["category"] == "No Match")
        not_signed_count = sum(1 for rows in resolved_teams.values() for row in rows if row["category"] == "Not Signed Up")
        print(f"{docx_path.name}: sheets={len(resolved_teams)} no_match={no_match_count} not_signed_up={not_signed_count}")

    review_groups = group_review_entries(all_review_entries)
    write_captain_email_list(all_resolved_teams, OUTPUT_DIR / "team-captains-email-list.txt")
    write_review_markdown(review_groups, BASE_DIR / "NO_MATCH_NAMES.md")
    write_review_markdown(review_groups, OUTPUT_DIR / "NO_MATCH_NAMES.md")
    write_review_pdf(review_groups, OUTPUT_DIR / "NO_MATCH_NAMES.pdf")


if __name__ == "__main__":
    main()
