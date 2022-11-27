Please see the most up-to-date version of this protocol on my blog at [https://darencard.net/blog/](https://darencard.net/blog/).

# Genome Annotation using MAKER

[MAKER](http://www.yandell-lab.org/software/maker.html) is a great tool for annotating a reference genome using empirical and *ab initio* gene predictions. [GMOD](http://gmod.org/wiki/Main_Page), the umbrella organization that includes MAKER, has some nice tutorials online for running MAKER. However, these were quite simplified examples and it took a bit of effort to wrap my head completely around everything. Here I will describe a *de novo* genome annotation for *Boa constrictor* in detail, so that there is a record and that it is easy to use this as a guide to annotate any genome.

## Software & Data

#### Software prerequisites:
 1. [RepeatModeler](http://www.repeatmasker.org/RepeatModeler/) and [RepeatMasker](http://www.repeatmasker.org/RMDownload.html) with all dependencies (I used NCBI BLAST) and [RepBase](http://www.girinst.org/repbase/) (version used was 20150807).
2. MAKER MPI version 2.31.8 (though any other version 2 releases should be okay).
3. [Augustus](http://bioinf.uni-greifswald.de/augustus/) version 3.2.3.
4. [BUSCO](http://busco.ezlab.org/) version 2.0.1.
5. [SNAP](http://korflab.ucdavis.edu/software.html) version 2006-07-28.
6. [BEDtools](https://bedtools.readthedocs.io/en/latest/) version 2.17.0.

#### Raw data/resources:
1. `Boa_constrictor_SGA_7C_scaffolds.fa`: The *de novo* *Boa constrictor* reference genome assembled as part of [Assemblathon2](http://dx.doi.org/10.1186/2047-217X-2-10). This is the SGA team assembly (snake 7C). This is in FASTA format.
2. `Boa_Trinity_15May2015.Txome_assembly.fasta`: A *de novo* transcriptome assembly created using [Trinity](https://github.com/trinityrnaseq/trinityrnaseq/wiki) and mRNAseq data from 10 *Boa* tissues. It may make sense to do some post-processing of this assembly, but I did not do so here. Trinity is pretty easy to run so I won't describe that here. This is in FASTA format.
3. Full protein amino acid sequences, in FASTA format, for three other Squamate species from [NCBI](https://www.ncbi.nlm.nih.gov/genome/) or [Ensembl](http://www.ensembl.org/index.html): *Anolis carolinensis*, *Python molurus bivittatus*, and *Thamnophis sirtalis*.
4. A curated snake repeat library derived from 14 snake species (from internal efforts).

#### Running commands:
I've become accustomed to running most programs (especially those that take hours/days) using `screen`. I would create new screens for each command below. I also like to use `tee` to keep track of run logs, as you will see in the commands below.

## Repeat Annotation

#### 1. *De Novo* Repeat Identification
The first, and very important, step to genome annotation is identifying repetitive content. Existing libraries from Repbase or from internal efforts are great, but it is also important to identify repeats *de novo* from your reference genome using `RepeatModeler`. This is pretty easy to do and normally only takes a couple days using 8-12 cores.

```bash
BuildDatabase -name Boa_constrictor -engine ncbi Boa_constrictor_SGA_7C_scaffolds.fa
RepeatModeler -pa 8 -engine ncbi -database Boa_constrictor 2>&1 | tee repeatmodeler.log
```

Further steps can be taken to annotate the resulting library, but the most important reason for this library is for downstream gene prediction. In this example, this *Boa* library was combined with several other snakes and annotated.

#### 2. Full Repeat Annotation
Depending on the species, the *de novo* library can be fed right into MAKER. We normally do more complex repeat identification with snakes so I will describe that here.

First, we mask using a currated BovB/CR1 line library to overcome a previously-identified issue with the Repbase annotation. This probably won't be necessary in other species.

```bash
mkdir BovB_mask
RepeatMasker -pa 8 -e ncbi -lib bovb_cr1_species.lib -dir BovB_mask Boa_constrictor_SGA_7C_scaffolds.fa
```

Then the maksed FASTA from this search can be used as input for the next search, using the `tetrapoda` library from Repbase. I also normally rename the outputs after each round so they are more representative of what they contain.

```bash
mkdir Tetrapoda_mask
RepeatMasker -pa 8 -e ncbi -species tetrapoda -dir Tetrapoda_mask Boa_constrictor_SGA_7C.scaffolds.BovB.fa
```

And then I finished using two more rounds using a library of known and unknown snake repeats (including those from *Boa*). These rounds were split so that known elements would be preferentially annotated over unknown, to the degree possible.

```bash
mkdir 14Snake_known_mask 14Snake_unknown_mask
RepeatMasker -pa 8 -e ncbi -species 14Snakes_Known_TElib.fasta -dir 14Snake_known_mask Boa_constrictor_SGA_7C.scaffolds.Tetrapoda.fa
RepeatMasker -pa 8 -e ncbi -species 14Snakes_Known_TElib.fasta -dir 14Snake_known_mask Boa_constrictor_SGA_7C.scaffolds.14SnakeKnown.fa
```

Finally, results from each round must be analyzed together to produce the final repeat annotation
```bash
mkdir Full_mask
cp 14snake_unknown_mask/Boa_constrictor_SGA_7C.scaffolds.14SnakeUnknown.fa Full_mask/Boa_constrictor_SGA_7C.scaffolds.full_mask.fa
cp 14snake_unknown_mask/Boa_constrictor_SGA_7C.scaffolds.14SnakeUnknown.out Full_mask/Boa_constrictor_SGA_7C.scaffolds.full_mask.out
gunzip BovB_mask/*.cat.gz Tetrapoda_mask/*.cat.gz 14snake_known_mask/*.cat.gz 14snake_unknown_mask/*.cat.gz
cat BovB_mask/*.cat Tetrapoda_mask/*.cat 14snake_known_mask/*.cat 14snake_unknown_mask/*.cat \
  > Final_mask/Boa_constrictor_SGA_7C.scaffolds.full_mask.cat
cd Full_mask
ProcessRepeats -species tetrapoda Final_mask/Boa_constrictor_SGA_7C.scaffolds.Full_mask.cat
```

Finally, in order to feed these repeats into MAKER properly, we must separate out the complex repeats (more info on this below).

```bash
# create GFF3
rmOutToGFF3.pl Full_mask/Boa_constrictor_SGA_7C.scaffolds.full_mask.out > Full_mask/Boa_constrictor_SGA_7C.scaffolds.full_mask.out.gff3
# isolate complex repeats
grep -v -e "Satellite" -e ")n" -e "-rich" Boa_constrictor_SGA_7C_scaffolds.full_mask.gff3 \
  > Boa_constrictor_SGA_7C_scaffolds.full_mask.complex.gff3
# reformat to work with MAKER
cat Boa_constrictor_SGA_7C_scaffolds.full_mask.complex.gff3 | \
  perl -ane '$id; if(!/^\#/){@F = split(/\t/, $_); chomp $F[-1];$id++; $F[-1] .= "\;ID=$id"; $_ = join("\t", @F)."\n"} print $_' \
  > Boa_constrictor_SGA_7C_scaffolds.full_mask.complex.reformat.gff3
```

Now we have the prerequesite data for running MAKER.

#### 3. Initial MAKER Analysis

MAKER is pretty easy to get going and relies on properly completed control files. These can be generated by issuing the command `maker -CTL`. The only control file we will be the `maker_opts.ctl` file. In this first round, we will obviously providing the data files for the repeat annotation (`rm_gff`), the transcriptome assembly (`est`), and for the other Squamate protein sequences (`protein`). We will also set the `model_org` to 'simple' so that only simple repeats are annotated (along with `RepeatRunner`). Here is the full control file for reference. 

```bash
cat round1_maker_opts.ctl

#-----Genome (these are always required)
genome=/home/castoelab/Desktop/daren/boa_annotation/Boa_constrictor_SGA_7C_scaffolds.fa #genome sequence (fasta file or fasta embeded in GFF3 file)
organism_type=eukaryotic #eukaryotic or prokaryotic. Default is eukaryotic

#-----Re-annotation Using MAKER Derived GFF3
maker_gff= #MAKER derived GFF3 file
est_pass=0 #use ESTs in maker_gff: 1 = yes, 0 = no
altest_pass=0 #use alternate organism ESTs in maker_gff: 1 = yes, 0 = no
protein_pass=0 #use protein alignments in maker_gff: 1 = yes, 0 = no
rm_pass=0 #use repeats in maker_gff: 1 = yes, 0 = no
model_pass=0 #use gene models in maker_gff: 1 = yes, 0 = no
pred_pass=0 #use ab-initio predictions in maker_gff: 1 = yes, 0 = no
other_pass=0 #passthrough anyything else in maker_gff: 1 = yes, 0 = no

#-----EST Evidence (for best results provide a file for at least one)
est=/home/castoelab/Desktop/daren/boa_annotation/Boa_Trinity_15May2015.Txome_assembly.fasta #set of ESTs or assembled mRNA-seq in fasta format
altest= #EST/cDNA sequence file in fasta format from an alternate organism
est_gff= #aligned ESTs or mRNA-seq from an external GFF3 file
altest_gff= #aligned ESTs from a closly relate species in GFF3 format

#-----Protein Homology Evidence (for best results provide a file for at least one)
protein=/home/castoelab/Desktop/daren/boa_annotation/protein_files_other_squamates/Anolis_carolinensis.AnoCar2.0.pep.all.fa,/home/castoelab/Desktop/daren/boa_annotation/protein_files_other_squamates/GCF_000186305.1_Python_molurus_bivittatus-5.0.2_protein.faa,/home/castoelab/Desktop/daren/boa_annotation/protein_files_other_squamates/GCF_001077635.1_Thamnophis_sirtalis-6.0_protein.faa  #protein sequence file in fasta format (i.e. from mutiple oransisms)
protein_gff=  #aligned protein homology evidence from an external GFF3 file

#-----Repeat Masking (leave values blank to skip repeat masking)
model_org=simple #select a model organism for RepBase masking in RepeatMasker
rmlib= #provide an organism specific repeat library in fasta format for RepeatMasker
repeat_protein=/opt/maker/data/te_proteins.fasta #provide a fasta file of transposable element proteins for RepeatRunner
rm_gff=/home/castoelab/Desktop/daren/boa_annotation/Full_mask/Boa_constrictor_SGA_7C_scaffolds.full_mask.complex.reformat.gff3 #pre-identified repeat elements from an external GFF3 file
prok_rm=0 #forces MAKER to repeatmask prokaryotes (no reason to change this), 1 = yes, 0 = no
softmask=1 #use soft-masking rather than hard-masking in BLAST (i.e. seg and dust filtering)

#-----Gene Prediction
snaphmm= #SNAP HMM file
gmhmm= #GeneMark HMM file
augustus_species= #Augustus gene prediction species model
fgenesh_par_file= #FGENESH parameter file
pred_gff= #ab-initio predictions from an external GFF3 file
model_gff= #annotated gene models from an external GFF3 file (annotation pass-through)
est2genome=1 #infer gene predictions directly from ESTs, 1 = yes, 0 = no
protein2genome=1 #infer predictions from protein homology, 1 = yes, 0 = no
trna=0 #find tRNAs with tRNAscan, 1 = yes, 0 = no
snoscan_rrna= #rRNA file to have Snoscan find snoRNAs
unmask=0 #also run ab-initio prediction programs on unmasked sequence, 1 = yes, 0 = no

#-----Other Annotation Feature Types (features MAKER doesn't recognize)
other_gff= #extra features to pass-through to final MAKER generated GFF3 file

#-----External Application Behavior Options
alt_peptide=C #amino acid used to replace non-standard amino acids in BLAST databases
cpus=1 #max number of cpus to use in BLAST and RepeatMasker (not for MPI, leave 1 when using MPI)

#-----MAKER Behavior Options
max_dna_len=100000 #length for dividing up contigs into chunks (increases/decreases memory usage)
min_contig=1 #skip genome contigs below this length (under 10kb are often useless)

pred_flank=200 #flank for extending evidence clusters sent to gene predictors
pred_stats=0 #report AED and QI statistics for all predictions as well as models
AED_threshold=1 #Maximum Annotation Edit Distance allowed (bound by 0 and 1)
min_protein=0 #require at least this many amino acids in predicted proteins
alt_splice=0 #Take extra steps to try and find alternative splicing, 1 = yes, 0 = no
always_complete=0 #extra steps to force start and stop codons, 1 = yes, 0 = no
map_forward=0 #map names and attributes forward from old GFF3 genes, 1 = yes, 0 = no
keep_preds=0 #Concordance threshold to add unsupported gene prediction (bound by 0 and 1)

split_hit=10000 #length for the splitting of hits (expected max intron size for evidence alignments)
single_exon=0 #consider single exon EST evidence when generating annotations, 1 = yes, 0 = no
single_length=250 #min length required for single exon ESTs if 'single_exon is enabled'
correct_est_fusion=0 #limits use of ESTs in annotation to avoid fusion genes

tries=2 #number of times to try a contig if there is a failure for some reason
clean_try=0 #remove all data from previous run before retrying, 1 = yes, 0 = no
clean_up=0 #removes theVoid directory with individual analysis files, 1 = yes, 0 = no
TMP= #specify a directory other than the system default temporary directory for temporary files
```

Specifying the GFF3 annotation file for the annotated complex repeats (`rm_gff`) has the effect of hard masking these repeats so that they do not confound our ability to identify coding genes. We let MAKER identify simple repeats internally, since it will soft mask these, allowing them to be available for gene annotation. This isn't a typical approach but has to be done if you want to do more than one succeessive round of RepeatMasker. I verified this would work with the MAKER maintainers [here](https://groups.google.com/forum/#!topic/maker-devel/patU-l_TQUM).

Two other important settings are `est2genome` and `protein2genome`, which are set to 1 so that MAKER gene predictions are based on the aligned transcripts and proteins (the only form of evidence we currently have). I also construct the MAKER command in a `Bash` script so it is easy to run and keep track of.

```bash
cat round1_run_maker.sh

mpiexec -n 12 maker -base Bcon_rnd1 round1_maker_opts.ctl maker_bopts.ctl maker_exe.ctl
```

Then we run MAKER.

```bash
bash ./round1_run_maker.sh 2>&1 | tee round1_run_maker.log
```

Given MAKER will be using BLAST to align transcripts and proteins to the genome, this will take at least a couple days with 12 cores. Speed is a product of the resources you allow (more cores == faster) and the assembly quality (smaller, less contiguous scaffolds == longer). We conclude by assembling together the GFF and FASTA outputs.

```bash
cd Bcon_rnd1.maker.output
gff3_merge -s -d Bcon_rnd1_master_datastore_index.log > Bcon_rnd1.all.maker.gff
fasta_merge -d Bcon_rnd1_master_datastore_index.log
# GFF w/o the sequences
gff3_merge -n -s -d Bcon_rnd1_master_datastore_index.log > Bcon_rnd1.all.maker.noseq.gff
```

#### 4. Training Gene Prediction Software

Besides mapping the empirical transcript and protein evidence to the reference genome and repeat annotation (not much of this in our example, given we've done so much up front), the most important product of this MAKER run is the gene models. These are what is used for training gene prediction software like `augustus` and `snap`.

###### SNAP

SNAP is pretty quick and easy to train. Issuing the following commands will perform the training. It is best to put some thought into what kind of gene models you use from MAKER. In this case, we use models with an AED of 0.25 or better and a length of 50 or more amino acids, which helps get rid of junky models.

```bash
mkdir snap
mkdir snap/round1
cd snap/round1
# export 'confident' gene models from MAKER and rename to something meaningful
maker2zff -x 0.25 -l 50 -d ../../Bcon_rnd1.maker.output/Bcon_rnd1_master_datastore_index.log
rename 's/genome/Bcon_rnd1.zff.length50_aed0.25/g' *
# gather some stats and validate
fathom Bcon_rnd1.zff.length50_aed0.25.ann Bcon_rnd1.zff.length50_aed0.25.dna -gene-stats > gene-stats.log 2>&1
fathom Bcon_rnd1.zff.length50_aed0.25.ann Bcon_rnd1.zff.length50_aed0.25.dna -validate > validate.log 2>&1
# collect the training sequences and annotations, plus 1000 surrounding bp for training
fathom Bcon_rnd1.zff.length50_aed0.25.ann Bcon_rnd1.zff.length50_aed0.25.dna -categorize 1000 > categorize.log 2>&1
fathom uni.ann uni.dna -export 1000 -plus > uni-plus.log 2>&1
# create the training parameters
mkdir params
cd params
forge ../export.ann ../export.dna > ../forge.log 2>&1
cd ..
# assembly the HMM
hmm-assembler.pl Bcon_rnd1.zff.length50_aed0.25 params > Bcon_rnd1.zff.length50_aed0.25.hmm
```

###### Augustus

Training Augustus is a more laborious process. Luckily, the recent release of `BUSCO` provides a nice pipeline for performing the training, while giving you an idea of how good your annotation already is. If you don't want to go this route, there are scripts provided with Augustus to perform the training. First, the `Parallel::ForkManager` module for Perl is required to run `BUSCO` with more than one core. You can easily install it before the first time you use `BUSCO` by running `sudo apt-get install libparallel-forkmanager-perl`.

This probably isn't an ideal training environment, but appears to work well. First, we must put together training sequences using the gene models we created in our first run of MAKER. We do this by issuing the following command to excise the regions that contain mRNA annotations based on our initial MAKER run (with 1000bp on each side).

```bash
awk -v OFS="\t" '{ if ($3 == "mRNA") print $1, $4, $5 }' ../../Bcon_rnd1.maker.output/Bcon_rnd1.all.maker.noseq.gff | \
  awk -v OFS="\t" '{ if ($2 < 1000) print $1, "0", $3+1000; else print $1, $2-1000, $3+1000 }' | \
  bedtools getfasta -fi ../../Boa_constrictor_SGA_7C_scaffolds.fa -bed - -fo Bcon_rnd1.all.maker.transcripts1000.fasta
```

There are some important things to note based on this approach. First is that you will likely get warnings from BEDtools that certain coordinates could not be used to extract FASTA sequences. This is because the end coordinate of a transcript plus 1000 bp is beyond the total length of a given scaffold. This script does account for transcripts being within the beginning 1000bp of the scaffold, but there was no easy way to do the same with transcrpts within the last 1000bp of the scaffold. This is okay, however, as we still end up with sequences from thousands of gene models and BUSCO will only be searching for a small subset of genes itself.

While we've only provided sequences from regions likely to contain genes, we've totally eliminated any existing annotation data about the starts/stops of gene elements. Augustus would normally use this as part of the training process. However, BUSCO will essentially do a reannotation of these regions using BLAST and built-in HMMs for a set of conserved genes (hundreds to thousands). This has the effect of recreating some version of our gene models for these conserved genes. We then leverage the internal training that BUSCO can perform (the `--long` argument) to optimize the HMM search model to train Augustus and produce a trained HMM for MAKER. Here is the command we use to perform the Augustus training inside BUSCO.

```bash
BUSCO.py -i Bcon_rnd2.all.maker.transcripts1000.fasta  -o Bcon_rnd1_maker -l tetrapoda_odb9/ \
  -m genome -c 8 --long -sp human -z --augustus_parameters='--progress=true'
```

In this case, we are using the Tetrapoda set of conserved genes (N = 3950 genes), so BUSCO will try to identify those gene using BLAST and an initial HMM model for each that comes stocked within BUSCO. We specify the `-m genome` option since we are giving BUSCO regions that include more than just transcripts. The initial HMM model we'll use is the human one (`-sp human`), which is a reasonably close species. Finally, the `--long` option tells BUSCO to use the initial gene models it creates to optimize the HMM settings of the raw human HMM, thus training it for our use on *Boa*. We can have this run in parallel on several cores, but it will still likely take days, so be patient.

Once BUSCO is complete, it will give you an idea of how complete your annotation is (though be cautious, because we haven't filtered away known alternative transcripts that will be binned as duplicates). We need to do some post-processing of the HMM models to get them ready for MAKER. First, we'll rename the files within `run_Bcon_rnd1_maker/augustus_output/retraining_paramters`.

```bash
rename 's/BUSCO_Bcon_rnd2_maker_2277442865/Boa_constrictor/g' *
```

We also need to rename the files cited within certain HMM configuration files.

```bash
sed -i 's/BUSCO_Bcon_rnd2_maker_2277442865/Boa_constrictor/g' Boa_constrictor_parameters.cfg
sed -i 's/BUSCO_Bcon_rnd2_maker_2277442865/Boa_constrictor/g' Boa_constrictor_parameters.cfg.orig1
```

Finally, we must copy these into the `$AUGUSTUS_CONFIG_PATH` species HMM location so they are accessible by Augustus and MAKER.

```bash
# may need to sudo
mkdir $AUGUSTUS_CONFIG_PATH/species/Boa_constrictor
cp Boa_constrictor*  $AUGUSTUS_CONFIG_PATH/species/Boa_constrictor/
```


#### 5. MAKER With *Ab Initio* Gene Predictors

Now let's run a second round of MAKER, but this time we will have SNAP and Augustus run within MAKER to help create more sound gene models. MAKER will use the annotations from these two prediction programs when constructing its models. Before running, let's first recycle the mapping of empicial evidence we have from the first MAKER round, so we don't have to perform all the BLASTs, etc. again.

```bash
# transcript alignments
awk '{ if ($2 == "est2genome") print $0 }' Bcon_rnd1.all.maker.noseq.gff > Bcon_rnd1.all.maker.est2genome.gff
# protein alignments
awk '{ if ($2 == "protein2genome") print $0 }' Bcon_rnd1.all.maker.noseq.gff > Bcon_rnd1.all.maker.protein2genome.gff
# repeat alignments
awk '{ if ($2 ~ "repeat") print $0 }' Bcon_rnd1.all.maker.noseq.gff > Bcon_rnd1.all.maker.repeats.gff
```

Then we will modify the previous control file, removing the FASTA sequences files to map and replacing them with the GFFs (`est_gff`, `protein_gff`, and `rm_gff`, respectively. We can also specify the path to the SNAP HMM and the species name for Augustus, so that these gene prediciton programs are run. We will also switch `est2genome` and `protein2genome` to 0 so that gene predictions are based on the Augustus and SNAP gene models. Here is the full version of this control file.

```bash
cat round2_maker_opts.ctl

#-----Genome (these are always required)
genome=/home/castoelab/Desktop/daren/boa_annotation/Boa_constrictor_SGA_7C_scaffolds.fa #genome sequence (fasta file or fasta embeded in GFF3 file)
organism_type=eukaryotic #eukaryotic or prokaryotic. Default is eukaryotic

#-----Re-annotation Using MAKER Derived GFF3
maker_gff= #MAKER derived GFF3 file
est_pass=0 #use ESTs in maker_gff: 1 = yes, 0 = no
altest_pass=0 #use alternate organism ESTs in maker_gff: 1 = yes, 0 = no
protein_pass=0 #use protein alignments in maker_gff: 1 = yes, 0 = no
rm_pass=0 #use repeats in maker_gff: 1 = yes, 0 = no
model_pass=0 #use gene models in maker_gff: 1 = yes, 0 = no
pred_pass=0 #use ab-initio predictions in maker_gff: 1 = yes, 0 = no
other_pass=0 #passthrough anyything else in maker_gff: 1 = yes, 0 = no

#-----EST Evidence (for best results provide a file for at least one)
est= #set of ESTs or assembled mRNA-seq in fasta format
altest= #EST/cDNA sequence file in fasta format from an alternate organism
est_gff=/home/castoelab/Desktop/daren/boa_annotation/Bcon_rnd1.maker.output/Bcon_rnd1.all.maker.est2genome.gff #aligned ESTs or mRNA-seq from an external GFF3 file
altest_gff= #aligned ESTs from a closly relate species in GFF3 format

#-----Protein Homology Evidence (for best results provide a file for at least one)
protein= #protein sequence file in fasta format (i.e. from mutiple oransisms)
protein_gff=/home/castoelab/Desktop/daren/boa_annotation/Bcon_rnd1.maker.output/Bcon_rnd1.all.maker.protein2genome.gff  #aligned protein homology evidence from an external GFF3 file

#-----Repeat Masking (leave values blank to skip repeat masking)
model_org= #select a model organism for RepBase masking in RepeatMasker
rmlib= #provide an organism specific repeat library in fasta format for RepeatMasker
repeat_protein= #provide a fasta file of transposable element proteins for RepeatRunner
rm_gff=/home/castoelab/Desktop/daren/boa_annotation/Bcon_rnd1.maker.output/Bcon_rnd1.all.maker.repeats.gff #pre-identified repeat elements from an external GFF3 file
prok_rm=0 #forces MAKER to repeatmask prokaryotes (no reason to change this), 1 = yes, 0 = no
softmask=1 #use soft-masking rather than hard-masking in BLAST (i.e. seg and dust filtering)

#-----Gene Prediction
snaphmm=/home/castoelab/Desktop/daren/boa_annotation/snap/round1/Bcon_rnd1.zff.length50_aed0.25.hmm #SNAP HMM file
gmhmm= #GeneMark HMM file
augustus_species=Boa_constrictor #Augustus gene prediction species model
fgenesh_par_file= #FGENESH parameter file
pred_gff= #ab-initio predictions from an external GFF3 file
model_gff= #annotated gene models from an external GFF3 file (annotation pass-through)
est2genome=0 #infer gene predictions directly from ESTs, 1 = yes, 0 = no
protein2genome=0 #infer predictions from protein homology, 1 = yes, 0 = no
trna=1 #find tRNAs with tRNAscan, 1 = yes, 0 = no
snoscan_rrna= #rRNA file to have Snoscan find snoRNAs
unmask=0 #also run ab-initio prediction programs on unmasked sequence, 1 = yes, 0 = no

#-----Other Annotation Feature Types (features MAKER doesn't recognize)
other_gff= #extra features to pass-through to final MAKER generated GFF3 file

#-----External Application Behavior Options
alt_peptide=C #amino acid used to replace non-standard amino acids in BLAST databases
cpus=1 #max number of cpus to use in BLAST and RepeatMasker (not for MPI, leave 1 when using MPI)

#-----MAKER Behavior Options
max_dna_len=300000 #length for dividing up contigs into chunks (increases/decreases memory usage)
min_contig=1 #skip genome contigs below this length (under 10kb are often useless)

pred_flank=200 #flank for extending evidence clusters sent to gene predictors
pred_stats=0 #report AED and QI statistics for all predictions as well as models
AED_threshold=1 #Maximum Annotation Edit Distance allowed (bound by 0 and 1)
min_protein=0 #require at least this many amino acids in predicted proteins
alt_splice=0 #Take extra steps to try and find alternative splicing, 1 = yes, 0 = no
always_complete=0 #extra steps to force start and stop codons, 1 = yes, 0 = no
map_forward=0 #map names and attributes forward from old GFF3 genes, 1 = yes, 0 = no
keep_preds=0 #Concordance threshold to add unsupported gene prediction (bound by 0 and 1)

split_hit=20000 #length for the splitting of hits (expected max intron size for evidence alignments)
single_exon=0 #consider single exon EST evidence when generating annotations, 1 = yes, 0 = no
single_length=250 #min length required for single exon ESTs if 'single_exon is enabled'
correct_est_fusion=0 #limits use of ESTs in annotation to avoid fusion genes

tries=2 #number of times to try a contig if there is a failure for some reason
clean_try=0 #remove all data from previous run before retrying, 1 = yes, 0 = no
clean_up=0 #removes theVoid directory with individual analysis files, 1 = yes, 0 = no
TMP= #specify a directory other than the system default temporary directory for temporary files
```

Then we can run MAKER, substituting this new control file, and summarize the output, as we did before.

#### 6. Iteratively Running MAKER to Improve Annotation

One of the beauties of MAKER is that it can be run iteratively, using the gene models from the one round to train *ab initio* software to improve the inference of gene models in the next round. Essentially, all one has to do is repeat steps 4 and 5 to perform another round of annotation. The MAKER creators/maintainers recommend at least a couple rounds of *ab initio* software training and MAKER annotation (i.e., 3 rounds total) and returns start to diminish (at differing rates) thereafter. One needs to be careful not to overtrain Augustus and SNAP, so more rounds isn't necessarily always better. Below are a few ways of evaluating your gene models after successive rounds of MAKER to identify when you have sound models.

A. Count the number of gene models and the gene lengths after each round.

```bash
cat <roundN.full.gff> | awk '{ if ($3 == "gene") print $0 }' | awk '{ sum += ($5 - $4) } END { print NR, sum / NR }'
```

B. Visualize the AED distribution. AED ranges from 0 to 1 and quantifies the confidence in a gene model based on empirical evidence. Basically, the lower the AED, the better a gene model is likely to be. Ideally, 95% or more of the gene models will have an AED of 0.5 or better in the case of good assemblies. You can use this [`AED_cdf_generator.pl`](https://github.com/mscampbell/Genome_annotation/blob/master/AED_cdf_generator.pl) script to help with this.

```bash
perl AED_cdf_generator.pl -b 0.025 <roundN.full.gff>
```

C. Run BUSCO one last time using the species Augustus HMM and take a look at the results (this will be quick since we are not training Augustus). Also, only include the transcript sequences (not the 1000 bp on each side) and be sure to take the best (i.e., longest) transcript for each gene so you aren't artificially seeding duplicates. You can also run it on the best protein sequence per gene instead. Your command will be some derivative of the following:

```bash
BUSCO.py -i <roundN.transcripts.fasta>  -o annotation_eval -l tetrapoda_odb9/ \
  -m transcriptome -c 8 -sp Boa_constrictor -z --augustus_parameters='--progress=true'
```

D. Visualize the gene models from Augustus, SNAP, and MAKER using a genome browser. [JBrowse](http://jbrowse.org/) is a good option for this. You can essentially follow [this guide](http://gmod.org/wiki/JBrowse_Configuration_Guide) to get this started. A helpful resource is this [`gff2jbrowse.pl`](https://github.com/wurmlab/afra/blob/master/bin/gff2jbrowse.pl) script, which automates adding tracks to the browser based on the GFF output of your MAKER run. It is best to use 5-10 longer, gene dense scaffolds and visually inspect them. When SNAP and Augustus are well trained, their models should overlap pretty closely with the final MAKER models. Moreover, there will be spurious hits from SNAP and Augustus, but they are usually short, 1-2 exon annotations and don't have empirical support. You'll get a sense of a good annotation with some experience. Also, it is possible SNAP won't produce good results, depending on your organism, which the MAKER folks have pointed out in the past (Augustus usually does pretty well).

#### 7. Downstream Processing and Homology Inference

After running MAKER one now has protein models, but that isn't all together very useful. First, the MAKER default names are long, ugly, and likely difficult for programs to parse. Moreover, even if they were named "gene1", etc. that doesn't tell you anything about what the genes actually are. Therefore, it is necessary to do some downstream processing of the MAKER output and to use homology searches against existing databases to annotate more functional information about genes.

A. First, let's rename the IDs that MAKER sets by default for genes and transcripts. MAKER comes with some scripts to do just this and to swap them out in the GFF and FASTA output (instructions for generated are above). The commands below first create custom IDs and store them as a table, and then use that table to rename the original GFF and FASTA files (they are overwritten, but it is possible to regenerate the raw ones again).

```bash
# create naming table (there are additional options for naming beyond defaults)
maker_map_ids --prefix BoaCon --justify 5  Bcon_rnd3.all.maker.gff > Bcon_rnd3.all.maker.name.map
# replace names in GFF files
map_gff_ids Bcon_rnd3.all.maker.name.map Bcon_rnd3.all.maker.gff
map_gff_ids Bcon_rnd3.all.maker.name.map Bcon_rnd3.all.maker.noseq.gff
# replace names in FASTA headers
map_fasta_ids Bcon_rnd3.all.maker.name.map Bcon_rnd3.all.maker.transcripts.fasta
map_fasta_ids Bcon_rnd3.all.maker.name.map Bcon_rnd3.all.maker.proteins.fasta
```