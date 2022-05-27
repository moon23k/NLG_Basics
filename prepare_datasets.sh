#!/bin/bash
mkdir -p data
cd data

datasets=(wmt daily)
splits=(train valid test)
extensions=(src trg)

#Create sub-dirs
for data in "${datasets[@]}"; do
    mkdir -p ${data}/seq ${data}/tok ${data}/ids ${data}/vocab
done

#Download Data
echo "Downloading Dataset"
python3 ../data_processing/download_wmt.py
bash ../data_processing/download_daily.sh
python3 ../data_processing/process_daily.py


#Pre tokenize with moses
echo "Pretokenize with moses"
python3 -m pip install -U sacremoses
for data in "${datasets[@]}"; do
    for split in "${splits[@]}"; do
        for ext in "${extensions[@]}"; do
            sacremoses -l en -j 8 tokenize < ${data}/seq/${split}.${ext} > ${data}/tok/${split}.${ext}
        done
    done
done


#Get sentencepiece
echo "Downloading Sentencepiece"
git clone https://github.com/google/sentencepiece.git
cd sentencepiece
mkdir build
cd build
cmake ..
make -j $(nproc)
sudo make install
sudo ldconfig
cd ../../


#Build Sentencepice Vocab and Model
echo "Building Vocabs"
for data in "${datasets[@]}"; do
    cat ${data}/tok/* > ${data}/concat.txt
    bash ../data_processing/build_vocab.sh -i ${data}/concat.txt -p ${data}/vocab/spm
    rm ${data}/concat.txt
done


#Tokens to Ids
echo "Converting Tokens to Ids"
for data in "${datasets[@]}"; do
    for split in "${splits[@]}"; do
        for ext in "${extensions[@]}"; do
            spm_encode --model=vocab/spm.model --extra_options=bos:eos \
            --output_format=id < ${data}/tok/${split}.${extensions} > ${data}/ids/${split}.${ext}
            echo " Converting Tokens to Ids on ${data}/${split}.${ext} has completed"
        done
    done
done
rm -rf sentencepiece