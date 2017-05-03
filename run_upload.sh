#!/bin/bash -ex

source paths-latest.sh

ssh compbiol@login.gwdg.de "mkdir -p -m 755 ~/www/uniclust/${RELEASE}"
scp ${TARGET}/uniclust{30,50,90}_${RELEASE}.tar.gz compbiol@login.gwdg.de:~/www/uniclust/${RELEASE}
scp ${TARGET}/uniclust_uniprot_mapping.tsv.gz compbiol@login.gwdg.de:~/www/uniclust/${RELEASE}

for i in 10 20 30; do
    ssh compbiol@login.gwdg.de "cd ~/www/uniclust/${RELEASE}/ && ln -s ~/www/uniclust/${BOOSTRELEASE}/uniboost${i}_${BOOSTRELEASE}.tar.gz uniboost${i}_${BOOSTRELEASE}.tar.gz"
done

ssh compbiol@login.gwdg.de "cd ~/www/uniclust/${RELEASE}/ && ln -s ~/www/uniclust/LICENSE.md LICENSE.md"
ssh compbiol@login.gwdg.de "chmod -R a+r ~/www/uniclust/${RELEASE}"
ssh compbiol@login.gwdg.de "~/www/uniclust/.change-release.sh ${RELEASE}"
