# #!/usr/bin/env bash
# # Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# # Apache 2.0

# [ -f ./path.sh ] && . ./path.sh

# # begin configuration section.
# cmd=run.pl
# min_lmwt=7
# max_lmwt=17
# #end configuration section.

# [ -f ./path.sh ] && . ./path.sh
# . parse_options.sh || exit 1;

# if [ $# -ne 3 ]; then
#   echo "Usage: local/score.sh [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir>"
#   echo " Options:"
#   echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
#   echo "    --min_lmwt <int>                # minumum LM-weight for lattice rescoring "
#   echo "    --max_lmwt <int>                # maximum LM-weight for lattice rescoring "
#   exit 1;
# fi

# data=$1
# lang_or_graph=$2
# dir=$3

# symtab=$lang_or_graph/words.txt

# for f in $symtab $dir/lat.1.gz $data/text; do
#   [ ! -f $f ] && echo "score.sh: no such file $f" && exit 1;
# done

# mkdir -p $dir/scoring/log

# cat $data/text | sed 's:<NOISE>::g' | sed 's:<SPOKEN_NOISE>::g' > $dir/scoring/test_filt.txt

# $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/best_path.LMWT.log \
#   lattice-best-path --lm-scale=LMWT --word-symbol-table=$symtab \
#     "ark:gunzip -c $dir/lat.*.gz|" ark,t:$dir/scoring/LMWT.tra || exit 1;

# # Note: the double level of quoting for the sed command
# $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/score.LMWT.log \
#    cat $dir/scoring/LMWT.tra \| \
#     utils/int2sym.pl -f 2- $symtab \| sed 's:\<UNK\>::g' \| \
#     compute-wer --text --mode=present \
#      ark:$dir/scoring/test_filt.txt  ark,p:- ">&" $dir/wer_LMWT || exit 1;

# # Show results
# for f in $dir/wer_*; do echo $f; egrep  '(WER)|(SER)' < $f; done

# exit 0;
#!/bin/bash
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# get variables before we run the script
( set -o posix ; set ) >variables.before

[ -f ./path.sh ] && . ./path.sh

# begin configuration section.
cmd=run.pl
stage=0
decode_mbr=true
word_ins_penalty=0.0
min_lmwt=9
max_lmwt=11
#end configuration section.

[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;


if [ $# -ne 5 ]; then
  echo "Usage: local/score.sh [--cmd (run.pl|queue.pl...)] <data-dir> <lang-dir|graph-dir> <decode-dir> <unknown_phone> <silence_phone>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1|2)                 # start scoring script from part-way through."
  echo "    --decode_mbr (true/false)       # maximum bayes risk decoding (confusion network)."
  echo "    --min_lmwt <int>                # minumum LM-weight for lattice rescoring "
  echo "    --max_lmwt <int>                # maximum LM-weight for lattice rescoring "
  echo "    --reverse (true/false)          # score with time reversed features "
  exit 1;
fi

data_dir=$1
lang_or_graph=$2
decode_dir=$3
unknown_phone=$4
silence_phone=$5
symbol_table=${lang_or_graph}/words.txt
verbose=false

if [ $verbose = true ]; then
    printf "\n###\n## BEGIN PARAMETERS FOR $0\n#\n\n"
    # get variables after we set them
    ( set -o posix ; set ) >variables.after
    # find and show the difference
    diff variables.before variables.after
    printf "\n#\n## END PARAMETERS FOR $0\n###\n\n"
fi
# remove files
rm -f variables.before variables.after

for file in $symbol_table ${decode_dir}/lat.1.gz ${data_dir}/text; do
    [ ! -f $file ] && echo "score.sh: no such file $file" && exit 1;
done

mkdir -p ${decode_dir}/scoring/log

cp ${data_dir}/text ${decode_dir}/scoring/test_true_transcripts.txt

# Note: double level of quoting to evaluate variable and put it in a new string
$cmd LMWT=$min_lmwt:$max_lmwt $decode_dir/scoring/log/prediction_final.LMWT.log \
    lattice-scale --inv-acoustic-scale=LMWT 'ark:gunzip -c '"${decode_dir}"'/lat.*.gz|' ark:- \| \
    lattice-add-penalty --word-ins-penalty=$word_ins_penalty ark:- ark:- \| \
    lattice-best-path --word-symbol-table=$symbol_table \
    ark:- ark,t:${decode_dir}/scoring/LMWT.tra \
    || exit 1;

$cmd LMWT=$min_lmwt:$max_lmwt ${decode_dir}/scoring/log/prediction_score.LMWT.log \
    cat ${decode_dir}/scoring/LMWT.tra \| \
    utils/int2sym.pl -f 2- $symbol_table \| sed 's:'"${silence_phone}"'::g' \| \
    compute-wer --text --mode=present \
    ark:${decode_dir}/scoring/test_true_transcripts.txt ark,p:- ">&" ${decode_dir}/wer_LMWT\
    || exit 1;

exit 0;
