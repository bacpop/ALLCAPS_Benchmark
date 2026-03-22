#!/usr/bin/env python3
"""Parse PneumoCaT results.xml into standardized CSV format.

Usage: parse_pneumocat.py <sample_id> <results.xml>
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
        # PneumoCaT XML: <result type="Serotype"><value>XX</value></result>
        # or <result type="Serotype Distinction"><value>XX</value></result>
        for result_elem in root.iter("result"):
            rtype = result_elem.get("type", "")
            if "Serotype" in rtype:
                val_elem = result_elem.find("value")
                if val_elem is not None and val_elem.text:
                    serotype = val_elem.text.strip()
                    break
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
