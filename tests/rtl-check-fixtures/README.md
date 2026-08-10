# Fixtures for the rtl-check workflow

Two designs: one clean, one carrying exactly one planted defect. The self-test
runs the reusable workflow against both and requires the clean one to pass and
the planted one to fail.

A check that has never been seen to fail is not a check. This is the rule the
estate applies to its other gates, applied here to the gate that runs in other
people's repositories.
