#!/usr/bin/env bash
source ../_PipelineCreationJob_/jobs/_PipelineCreationJob_/000_Config.sh
figlet -w 500 "${STAGE_NAME}"

# TODO: Performance, K6.
echo Not implemented.

#export CYPRESS_RECORD_KEY=credentials('CypressRecordKey')
#npm install
#./node_modules/.bin/cypress run --record --key ${CYPRESS_RECORD_KEY}
