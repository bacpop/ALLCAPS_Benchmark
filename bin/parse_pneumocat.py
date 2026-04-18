#!/usr/bin/env python3
"""Parse PneumoCaT results.xml into standardized CSV format.

Usage: parse_pneumocat.py <sample_id> <results.xml>

The XML looks like this:
    <ngs_sample id="ERR10419726">
    <workflow value="PneumoCaT" version="1.2.1"/>
    <results>
        <result type="Serotype" value="07C">
        ...

Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys
import xml.etree.ElementTree as ET


def parse_pneumocat(sample_id: str, xml_path: str) -> str:
    serotype = "FAILED"
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        # Find the <result> element with type="Serotype"
        for result in root.findall(".//result[@type='Serotype']"):
            serotype = result.get("value", "FAILED")
            break  # We only care about the first one
    except ET.ParseError:
        pass
    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <results.xml>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    xml_path = sys.argv[2]
    serotype = parse_pneumocat(sample_id, xml_path)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "PneumoCaT", serotype])


if __name__ == "__main__":
    main()
