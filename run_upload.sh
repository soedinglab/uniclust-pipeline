#!/bin/bash -ex

source paths-latest.sh

DOWNLOADSBASE="~/www/uniclust"

ssh compbiol@login.gwdg.de "mkdir -p -m 755 ${DOWNLOADSBASE}/${RELEASE}"
scp ${TARGET}/uniclust{30,50,90}_${RELEASE}.tar.gz compbiol@login.gwdg.de:"${DOWNLOADSBASE}/${RELEASE}"
scp ${TARGET}/uniclust_uniprot_mapping.tsv.gz compbiol@login.gwdg.de:"${DOWNLOADSBASE}/${RELEASE}"

for i in 10 20 30; do
    ## TODO: upload full release
    ssh compbiol@login.gwdg.de "cd ${DOWNLOADSBASE}/${RELEASE}/ && ln -s ${DOWNLOADSBASE}/${BOOSTRELEASE}/uniboost${i}_${BOOSTRELEASE}.tar.gz uniboost${i}_${BOOSTRELEASE}.tar.gz"
done

ssh compbiol@login.gwdg.de "cd ${DOWNLOADSBASE}/${RELEASE}/ && ln -s ${DOWNLOADSBASE}/LICENSE.md LICENSE.md"
ssh compbiol@login.gwdg.de "chmod -R a+r ${DOWNLOADSBASE}/${RELEASE}"
ssh compbiol@login.gwdg.de "${DOWNLOADSBASE}/.change-release.sh ${RELEASE}"
