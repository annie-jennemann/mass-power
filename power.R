#!/usr/bin/env python3
"""Update and publish the Massachusetts power-outage Datawrapper chart."""

from __future__ import annotations

import csv
import json
import os
import sys
import time
from datetime import datetime
from decimal import Decimal, InvalidOperation
from io import StringIO
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo


OUTAGE_URL = "http://mema.mapsonline.net/power_outage_public.csv"
CHART_ID = "cP5ai"
DATAWRAPPER_API_URL = "https://api.datawrapper.de/v3"
USER_AGENT = "Mozilla/5.0 (GitHub Actions; Python)"


def request_with_retries(
    request: Request, *, attempts: int = 8, timeout: int = 120
) -> bytes:
    """Perform an HTTP request, retrying transient failures with backoff."""
    last_error: Exception | None = None

    for attempt in range(attempts):
        try:
            with urlopen(request, timeout=timeout) as response:
                return response.read()
        except (HTTPError, URLError, TimeoutError) as error:
            last_error = error
            if isinstance(error, HTTPError) and error.code not in {
                408,
                425,
                429,
                500,
                502,
                503,
                504,
            }:
                raise
            if attempt == attempts - 1:
                break
            time.sleep(min(2**attempt, 30))

    raise RuntimeError(f"Request failed after {attempts} attempts: {last_error}")


def fetch_total() -> tuple[Decimal, list[dict[str, str]]]:
    request = Request(OUTAGE_URL, headers={"User-Agent": USER_AGENT})
    raw_csv = request_with_retries(request).decode("utf-8-sig")
    rows = list(csv.DictReader(StringIO(raw_csv)))

    if not rows or "Without Power" not in rows[0]:
        raise ValueError("CSV does not contain a 'Without Power' column")

    total = Decimal("0")
    for row in rows:
        value = (row.get("Without Power") or "").strip().replace(",", "")
        if not value:
            continue
        try:
            total += Decimal(value)
        except InvalidOperation as error:
            raise ValueError(f"Invalid 'Without Power' value: {value!r}") from error

    return total, rows[:5]


def format_timestamp() -> str:
    now = datetime.now(ZoneInfo("America/New_York"))
    # %-d and %-I produce the same no-leading-zero formatting as the R code.
    formatted = now.strftime("%B %-d at %-I:%M %p EST")
    return formatted.replace("AM", "a.m.").replace("PM", "p.m.")


def update_chart(api_key: str, title: str, annotation: str) -> None:
    url = f"{DATAWRAPPER_API_URL}/charts/{CHART_ID}"
    payload = {
        "title": title,
        "metadata": {"annotate": {"notes": annotation}},
    }
    request = Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="PATCH",
    )
    request_with_retries(request, timeout=120)

    publish_request = Request(
        f"{url}/publish",
        data=b"{}",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    request_with_retries(publish_request, timeout=120)


def main() -> int:
    api_key = os.environ.get("API_KEY")
    if not api_key:
        print("Missing required API_KEY environment variable.", file=sys.stderr)
        return 2

    total, first_rows = fetch_total()
    print("First rows:")
    for row in first_rows:
        print(row)

    total_text = f"{total:,.0f}"
    title = f"<b>{total_text}</b> customers are without power in Massachusetts"
    annotation = f"Chart updated {format_timestamp()}"

    update_chart(api_key, title, annotation)
    print(title)
    print(annotation)
    print(f"Published Datawrapper chart {CHART_ID}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
