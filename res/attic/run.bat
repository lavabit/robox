@echo off

set VERSION=0.8.20
set ATLAS_TOKEN=qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE

REM Validate the Hyper-V JSON template.
packer validate magma-hyperv.json

REM Build the magma boxes for Hyper-V.
packer build -color=false -on-error=cleanup -parallel=false magma-hyperv.json
