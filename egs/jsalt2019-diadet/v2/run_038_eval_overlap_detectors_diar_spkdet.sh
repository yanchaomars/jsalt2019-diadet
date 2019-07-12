#!/bin/bash
# Copyright      2019   JSALT workshop (Author: Diego Castan)
#
# Apache 2.0.
#
. ./cmd.sh
. ./path.sh
set -e

stage=3


config_file=default_config.sh

. parse_options.sh || exit 1;
. $config_file

exp_dir=exp/overlap_models
out_dir=${exp_dir}/test_raw
config_overlap=config.yml

# SRI overlap model is trained in CHiME5
# tst_vec=(AMI.SpeakerDiarization.MixHeadset BabyTrain.SpeakerDiarization.All SRI.SpeakerDiarization.All)
tst_vec=(AMI.SpeakerDiarization.MixHeadset)
num_dbs=${#tst_vec[@]}

##### TO DO ####
# We select just the net that we want for development purposes
# The net should be selected based on the validation file (nets are still on a training stage)
ovnet=${exp_dir}/train/AMI.SpeakerDiarization.MixHeadset.train/weights/0422.pt
###############

#Train overlap
if [ $stage -le 1 ];then

    mkdir -p $out_dir
    # Train a overlap detection model based on LSTM and SyncNet features
    echo "Test overlap detector"
    for((i=0;i<$num_dbs;i++))
    do
        db=${tst_vec[$i]}
        ( 
            $train_cmd_gpu $exp_dir/log/test_${i}.log \
	       ./local/test_overlap.sh $ovnet $db ${out_dir} || exit 1;
        ) &
    done

fi
wait

# thresholding and conversion
if [ $stage -le 2 ];then

    # Train a overlap detection model based on LSTM and SyncNet features
    echo "Thresholding and converting..."
    for((i=0;i<$num_dbs;i++))
    do
        db=${tst_vec[$i]}
        ( 
            $train_cmd $exp_dir/log/thrcov_${i}.log \
	       ./local/thr_and_conv_overlap.sh $db ${out_dir} || exit 1;
        ) &
    done

fi
wait

# To Kaldi format and RTTM for overlap spkdet
if [ $stage -le 3 ];then

    # Train a overlap detection model based on LSTM and SyncNet features
    echo "Covert to Kaldi for SpkDet and VAD RTTM for SpkDet"
    # for dsetname in babytrain ami sri
    for dsetname in ami
    do
    ovtxt=${out_dir}/overlap_${dsetname}.txt
    ./local/diar2spkdet.py ${ovtxt} ${out_dir}
    dset=jsalt19_spkdet_${dsetname}_eval_test
    cut -d' ' -f1 data/${dset}/segments | fgrep -f - ${out_dir}/overlap.rttm > data/${dset}/overlap.rttm
    cut -d' ' -f1 data/${dset}/segments | fgrep -f - ${out_dir}/segoverlap > data/${dset}/segoverlap
    done

fi
