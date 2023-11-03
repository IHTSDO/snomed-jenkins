#!/usr/bin/env bash
source ../_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

cat<<EOF
Not implemented.

Maybe delete large files with:

    find . -type f -size +1M -delete

This will delete large files from this location and below:
EOF

pwd
