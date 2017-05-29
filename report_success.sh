#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-mail.%J
#BSUB -e log-mail.%J
#BSUB -W 1:00
#BSUB -n 1
#BSUB -m hh

source paths-latest.sh

if [[ -n "$REPORT_MAIL_1" ]]; then
	echo "Done" | mail -s "Successfully finished Uniclust Update Workflow" "$REPORT_MAIL_1"
fi

if [[ -n "$REPORT_MAIL_2" ]]; then
	echo "Done" | mail -s "Successfully finished Uniclust Update Workflow" "$REPORT_MAIL_2"
fi

if [[ -n "$REPORT_MAIL_3" ]]; then
	echo "Done" | mail -s "Successfully finished Uniclust Update Workflow" "$REPORT_MAIL_3"
fi

if [[ -n "$REPORT_MAIL_3" ]]; then
	echo "Done" | mail -s "Successfully finished Uniclust Update Workflow" "$REPORT_MAIL_3"
fi
