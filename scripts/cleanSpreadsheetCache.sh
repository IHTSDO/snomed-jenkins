#!/usr/bin/env bash

echo "-------------------------------------------------------------"
echo "Before"
ls -l /tmp/*.[tc]sv
echo "-------------------------------------------------------------"

if [[ -e "/tmp/ProjectsDSL.csv" ]]; then
    echo "Removing: /tmp/ProjectsDSL.csv"
    rm /tmp/ProjectsDSL.csv
else
    echo "/tmp/ProjectsDSL.csv already removed."
fi

echo "-------------------------------------------------------------"

if [[ -e "/tmp/jira_components_cache.tsv" ]]; then
    echo "Removing /tmp/jira_components_cache.tsv"
    rm /tmp/jira_components_cache.tsv
else
    echo "/tmp/jira_components_cache.tsv already removed."
fi

echo "-------------------------------------------------------------"
echo "After"
ls -l /tmp/*.[tc]sv
echo "-------------------------------------------------------------"

echo "Output all variables for this run:"
echo
set
echo "-------------------------------------------------------------"
