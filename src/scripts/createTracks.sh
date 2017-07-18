#!/bin/bash

pushd `dirname $0` > /dev/null
AL_DIR_TOOLS=`pwd -P` # get the full path to itself
popd > /dev/null

#source $AL_DIR_TOOLS/alea.config
source /alea-data/alea.config


if test $# -ne 8
then
    echo "
Usage:   
         alea createTracks <-s/-p> bamPrefix strain1 strain2 genome1.refmap genome2.refmap chrom.sizes outputDIR
         
Options:
         -s to create tracks for the single-end aligned reads
         -p to create tracks for the paired-end aligned reads

         bamPrefix      prefix used for the output of alignReads command
         strain1        name of strain1 (e.g. hap1)
         strain2        name of strain2 (e.g. hap2)
         genome1.refmap path to the refmap file created for insilico genome 1
         genome1.refmap path to the refmap file created for insilico genome 2
         chrom.sizes    path to the chromosome size file (required for creating .bw)
         outputDIR      output directory (where to create track files)
         
Output:
         outputDIR/outputPrefix_strain1.bedGraph
         outputDIR/outputPrefix_strain1.bw        read profiles for strain1 projected to reference genome
         
         outputDIR/outputPrefix_strain2.bedGraph 
         outputDIR/outputPrefix_strain2.bw        read profiles for strain2 projected to reference genome
         
         outputDIR/outputPrefix_strain1.wig.gz
         outputDIR/outputPrefix_strain2.wig.gz    unprojected read profiles for strain1 and strain2
"
exit 1
fi

##############################################################################
#############   Module 4: projection to reference genome
##############################################################################

###converts bam to wig using bedtools
function BAM2WIGbedtools {
    local PARAM_INPUT_PREFIX=$1
    local PARAM_OUTPUT_DIR=$2
    local PARAM_CHROM_SIZES=$3
    
    local VAR_q=$AL_BAM2WIG_PARAM_MIN_QUALITY     # min read quality [0]
    local VAR_F=$AL_BAM2WIG_PARAM_FILTERING_FLAG  # filtering flag [0]
    local VAR_x=$AL_BAM2WIG_PARAM_SE_EXTENSION    # average fragment length used for fixed length of the read extension [0]. used for ChIP-seq (SET) only
    local VAR_INPUT_BASENAME=`basename $PARAM_INPUT_PREFIX`
    
    aleaCheckFileExists "$PARAM_INPUT_PREFIX".bam
    $AL_BIN_SAMTOOLS view -bh -F "$VAR_F" -q "$VAR_q" "$PARAM_INPUT_PREFIX".bam > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam
    
    if [ "$VAR_OPTION" = "-s" ]; then
        if [ $AL_USE_BWA = 1 ] || [ $AL_USE_BOWTIE1 = 1 ] || [ $AL_USE_BOWTIE2 = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -fs "$VAR_x" -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        elif [ $AL_USE_BISMARK = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        elif [ $AL_USE_STAR = 1 ] || [ $AL_USE_TOPHAT2 = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -split -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        fi
    elif [ "$VAR_OPTION" = "-p" ]; then
        if [ $AL_USE_BWA = 1 ] || [ $AL_USE_BOWTIE1 = 1 ] || [ $AL_USE_BOWTIE2 = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -pc -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        elif [ $AL_USE_BISMARK = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        elif [ $AL_USE_STAR = 1 ] || [ $AL_USE_TOPHAT2 = 1 ]; then
            $AL_BIN_BEDTOOLS genomecov -bg -split -ibam "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bam -g "$PARAM_CHROM_SIZES" \
                > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph
        fi
    else
        echo "Invalid option $VAR_OPTION"
        exit 1
    fi
    sort -k1,1 -k2,2n "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q"_unsorted.bedGraph > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bedGraph "$PARAM_CHROM_SIZES" "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bw #output this file for viz
    
    awk 'BEGIN {
        print "track type=wiggle_0"
    }
    NF == 4 {
        print "fixedStep chrom="$1" start="$2+1" step=1 span=1"
        for(i = 0; i < $3-$2; i++) {
            print $4
        }
    }' "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bedGraph > "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".wig
    $AL_BIN_BGZIP -c "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".wig > "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".wig.gz
    mv "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bedGraph "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".bedGraph
    mv "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".bw "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".bw
    if [ $AL_DEBUG = 0 ]; then
        rm "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".wig
    else
        mv "$PARAM_INPUT_PREFIX"_F"$VAR_F"_q"$VAR_q".wig "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".wig
    fi
}

### Converts filtered bam files to wig
#function convertBam2WigSE {
#    local PARAM_INPUT_PREFIX=$1
#    local PARAM_OUTPUT_DIR=$2
#    
#    local VAR_q=$AL_BAM2WIG_PARAM_MIN_QUALITY     # min read quality [0]
#    local VAR_F=$AL_BAM2WIG_PARAM_FILTERING_FLAG  # filtering flag [0]
#    local VAR_x=$AL_BAM2WIG_PARAM_SE_EXTENSION    # average fragment length used for fixed length of the read extension [0]. used for ChIP-seq (SET) only
#    local VAR_INPUT_BASENAME=`basename $PARAM_INPUT_PREFIX`
#    
#    aleaCheckFileExists "$PARAM_INPUT_PREFIX".bam
#    
#    # Create a wig profile from the bam file
#    $AL_BIN_BAM2WIG \
#        -samtools $AL_BIN_SAMTOOLS \
#        -bamFile "$PARAM_INPUT_PREFIX".bam \
#        -out $PARAM_OUTPUT_DIR/ \
#        -q $VAR_q \
#        -F $VAR_F \
#        -cs \
#        -x $VAR_x
#    
#    mv $PARAM_OUTPUT_DIR/$VAR_INPUT_BASENAME.q"$VAR_q".F"$VAR_F".SET_"$VAR_x".wig.gz $PARAM_OUTPUT_DIR/$VAR_INPUT_BASENAME.wig.gz
#}
#
#function convertBam2WigPE {
#    local PARAM_INPUT_PREFIX=$1
#    local PARAM_OUTPUT_DIR=$2
#    
#    local VAR_q=$AL_BAM2WIG_PARAM_MIN_QUALITY     # min read quality [0]
#    local VAR_F=$AL_BAM2WIG_PARAM_FILTERING_FLAG  # filtering flag [0]
#    local VAR_x=$AL_BAM2WIG_PARAM_SE_EXTENSION    # average fragment length used for fixed length of the read extension [0]. used for ChIP-seq (SET) only
#    local VAR_INPUT_BASENAME=`basename $PARAM_INPUT_PREFIX`
#    
#    aleaCheckFileExists "$PARAM_INPUT_PREFIX".bam
#    
#    # Create a wig profile from the bam file
#    $AL_BIN_BAM2WIG \
#        -samtools $AL_BIN_SAMTOOLS \
#        -bamFile "$PARAM_INPUT_PREFIX".bam \
#        -out $PARAM_OUTPUT_DIR/ \
#        -q $VAR_q \
#        -F $VAR_F \
#        -cp \
#        -x $VAR_x
#    
#    mv "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".q"$VAR_q".F"$VAR_F".PET.wig.gz "$PARAM_OUTPUT_DIR"/"$VAR_INPUT_BASENAME".wig.gz
#}


### projects a wig profile to reference genome
function projectToReferenceGenome {
    local PARAM_WIG_FILE=$1
    local PARAM_REFMAP_FILE=$2
    local PARAM_BEDGRAPH_FILE=$3
    
    aleaCheckFileExists "$PARAM_WIG_FILE"
    aleaCheckFileExists "$PARAM_REFMAP_FILE"
    
    printProgress "Started projectToReferenceGenome"
    
    $AL_BIN_ALEA project\
        --input-wig=$PARAM_WIG_FILE\
        --input-refmap=$PARAM_REFMAP_FILE\
        --output-bedgraph=$PARAM_BEDGRAPH_FILE
    
    printProgress "Finished projectToReferenceGenome"
}

### merge a cytosine report into a CpG site report
function mergeTwoStrandMethylation {
    local PARAM_CYTESINE_REPORT_FILE=$1
    local PARAM_SITE_REPORT_FILE=$2
    
    aleaCheckFileExists "$PARAM_CYTESINE_REPORT_FILE"
    
    printProgress "Started mergeTwoStrandMethylation"
    
    awk '
        BEGIN{
            FS = "\t"
            OFS = "\t"
            
            FIRST_POS = 0
            FIRST_METHYL = 0
            FIRST_UNMETHYL = 0
            METHYL = 0
            UNMETHYL = 0
            FIRST_TRI = ""
        }
        $3 == "+"{
            FIRST_POS = $2
            FIRST_METHYL = $4
            FIRST_UNMETHYL = $5
            FIRST_TRI = $7
        }
        $3 == "-"{
            if ($2 == FIRST_POS + 1) {
                METHYL = FIRST_METHYL + $4
                UNMETHYL = FIRST_UNMETHYL + $5
                
                if (METHYL + UNMETHYL > 0) {
                    printf $1 "\t" FIRST_POS "\t" $2 "\t"
                    printf "%6f\t", METHYL / (METHYL + UNMETHYL) * 100.0
                    print METHYL, UNMETHYL, $6, FIRST_TRI
                }
                else {
                    print $1, FIRST_POS, $2, "NA", METHYL, UNMETHYL, $6, FIRST_TRI
                }
            }
            FIRST_POS = 0
            FIRST_METHYL = 0
            FIRST_UNMETHYL = 0
            FIRST_TRI = ""
            METHYL = 0
            UNMETHYL = 0
        }
    ' "$PARAM_CYTESINE_REPORT_FILE" > "$PARAM_SITE_REPORT_FILE"
    
    printProgress "Finished mergeTwoStrandMethylation"
}

### convert a CpG site report into a Wig
function convertMethylationToWig {
    local PARAM_SITE_REPORT_FILE=$1
    local PARAM_WIG_FILE=$2
    
    local VAR_MIN_DEPTH=$AL_METH2WIG_PARAM_MIN_DEPTH
    
    aleaCheckFileExists "$PARAM_SITE_REPORT_FILE"
    
    printProgress "Started convertMethylationToWig"
    
    awk -v MIN_DEPTH=$VAR_MIN_DEPTH '
        BEGIN{
            FS = "\t"
            OFS = "\t"
            
            if (MIN_DEPTH < 1)
                MIN_DEPTH = 1
            
            print "track type=wiggle_0"
        }
        $5 + $6 >= MIN_DEPTH{
            print "fixedStep chrom=" $1 " start=" $2 " step=1 span=1"
            for(i = 0; i < $3-$2+1; i++)
                print $4
        }
    ' "$PARAM_SITE_REPORT_FILE" > "$PARAM_WIG_FILE"
    
    printProgress "Finished convertMethylationToWig"
}

### convert a CpG site report into a BedGraph
function convertMethylationToBedgraph {
    local PARAM_SITE_REPORT_FILE=$1
    local PARAM_BEDGRAPH_FILE=$2
    
    local VAR_MIN_DEPTH=$AL_METH2WIG_PARAM_MIN_DEPTH
    
    aleaCheckFileExists "$PARAM_SITE_REPORT_FILE"
    
    printProgress "Started convertMethylationToBedgraph"
    
    awk -v MIN_DEPTH=$VAR_MIN_DEPTH '
        BEGIN{
            FS = "\t"
            OFS = "\t"
            
            if (MIN_DEPTH < 1)
                MIN_DEPTH = 1
            
            print "track type=bedGraph"
        }
        $5 + $6 >= MIN_DEPTH{
            print $1, $2 - 1, $3, $4
        }
    ' "$PARAM_SITE_REPORT_FILE" > "$PARAM_BEDGRAPH_FILE"
    
    printProgress "Finished convertMethylationToBedgraph"
}


VAR_OPTION=$1
shift

#function generateAllelicTracks {
    PARAM_BAM_PREFIX=$1
    PARAM_STRAIN1=$2
    PARAM_STRAIN2=$3
    PARAM_REFMAP_FILE1=$4
    PARAM_REFMAP_FILE2=$5
    PARAM_CHROM_SIZES=$6
    PARAM_OUTPUT_DIR=$7
    PARAM_OUTPUT_DIR=$7
    
    aleaCheckFileExists "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN1".bam
    aleaCheckFileExists "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN2".bam
    aleaCheckFileExists "$PARAM_REFMAP_FILE1"
    aleaCheckFileExists "$PARAM_REFMAP_FILE2"
    aleaCheckFileExists "$PARAM_CHROM_SIZES"
    aleaCreateDir "$PARAM_OUTPUT_DIR"
    
    VAR_OUTPUT_BASENAME=`basename $PARAM_BAM_PREFIX`
    VAR_OUTPUT_PREFIX1="$PARAM_OUTPUT_DIR"/"$VAR_OUTPUT_BASENAME"_"$PARAM_STRAIN1"
    VAR_OUTPUT_PREFIX2="$PARAM_OUTPUT_DIR"/"$VAR_OUTPUT_BASENAME"_"$PARAM_STRAIN2"
    
    BAM2WIGbedtools "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN1" "$PARAM_OUTPUT_DIR" "$PARAM_CHROM_SIZES"
    BAM2WIGbedtools "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN2" "$PARAM_OUTPUT_DIR" "$PARAM_CHROM_SIZES"
    mv "$VAR_OUTPUT_PREFIX1".wig.gz "$VAR_OUTPUT_PREFIX1"_preProject.wig.gz
    mv "$VAR_OUTPUT_PREFIX2".wig.gz "$VAR_OUTPUT_PREFIX2"_preProject.wig.gz
    mv "$VAR_OUTPUT_PREFIX1".bedGraph "$VAR_OUTPUT_PREFIX1"_preProject.bedGraph
    mv "$VAR_OUTPUT_PREFIX2".bedGraph "$VAR_OUTPUT_PREFIX2"_preProject.bedGraph
    mv "$VAR_OUTPUT_PREFIX1".bw "$VAR_OUTPUT_PREFIX1"_preProject.bw
    mv "$VAR_OUTPUT_PREFIX2".bw "$VAR_OUTPUT_PREFIX2"_preProject.bw
    if [ $AL_DEBUG != 0 ]; then
        mv "$VAR_OUTPUT_PREFIX1".wig "$VAR_OUTPUT_PREFIX1"_preProject.wig
        mv "$VAR_OUTPUT_PREFIX2".wig "$VAR_OUTPUT_PREFIX2"_preProject.wig
    fi
    
    projectToReferenceGenome "$VAR_OUTPUT_PREFIX1"_preProject.wig.gz "$PARAM_REFMAP_FILE1" "$VAR_OUTPUT_PREFIX1".bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$VAR_OUTPUT_PREFIX1".bedGraph "$PARAM_CHROM_SIZES" "$VAR_OUTPUT_PREFIX1".bw
    
    projectToReferenceGenome "$VAR_OUTPUT_PREFIX2"_preProject.wig.gz "$PARAM_REFMAP_FILE2" "$VAR_OUTPUT_PREFIX2".bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$VAR_OUTPUT_PREFIX2".bedGraph "$PARAM_CHROM_SIZES" "$VAR_OUTPUT_PREFIX2".bw
    
    BAM2WIGbedtools "$PARAM_BAM_PREFIX"_total "$PARAM_OUTPUT_DIR" "$PARAM_CHROM_SIZES"

#}

if [ $AL_USE_BISMARK = 1 ]; then
#function generateAllelicMethylTracks {
    VAR_OUTPUT_PREFIX_TOTAL="$PARAM_OUTPUT_DIR"/"$VAR_OUTPUT_BASENAME"_total
    VAR_BAM_PREFIX_1_2="$PARAM_BAM_PREFIX"_"$PARAM_STRAIN1"_"$PARAM_STRAIN2"
    VAR_OUTPUT_PREFIX_1_2="$PARAM_OUTPUT_DIR"/"$VAR_OUTPUT_BASENAME"_"$PARAM_STRAIN1"_"$PARAM_STRAIN2"
    
    mv "$VAR_OUTPUT_PREFIX1".bedGraph "$VAR_OUTPUT_PREFIX1"_coverage.bedGraph
    mv "$VAR_OUTPUT_PREFIX2".bedGraph "$VAR_OUTPUT_PREFIX2"_coverage.bedGraph
    mv "$VAR_OUTPUT_PREFIX1".bw "$VAR_OUTPUT_PREFIX1"_coverage.bw
    mv "$VAR_OUTPUT_PREFIX2".bw "$VAR_OUTPUT_PREFIX2"_coverage.bw
    mv "$VAR_OUTPUT_PREFIX1"_preProject.wig.gz "$VAR_OUTPUT_PREFIX1"_preProject_coverage.wig.gz
    mv "$VAR_OUTPUT_PREFIX2"_preProject.wig.gz "$VAR_OUTPUT_PREFIX2"_preProject_coverage.wig.gz
    mv "$VAR_OUTPUT_PREFIX1"_preProject.bedGraph "$VAR_OUTPUT_PREFIX1"_preProject_coverage.bedGraph
    mv "$VAR_OUTPUT_PREFIX2"_preProject.bedGraph "$VAR_OUTPUT_PREFIX2"_preProject_coverage.bedGraph
    mv "$VAR_OUTPUT_PREFIX1"_preProject.bw "$VAR_OUTPUT_PREFIX1"_preProject_coverage.bw
    mv "$VAR_OUTPUT_PREFIX2"_preProject.bw "$VAR_OUTPUT_PREFIX2"_preProject_coverage.bw
    mv "$VAR_OUTPUT_PREFIX_TOTAL".bedGraph "$VAR_OUTPUT_PREFIX_TOTAL"_coverage.bedGraph
    mv "$VAR_OUTPUT_PREFIX_TOTAL".bw "$VAR_OUTPUT_PREFIX_TOTAL"_coverage.bw
    mv "$VAR_OUTPUT_PREFIX_TOTAL".wig.gz "$VAR_OUTPUT_PREFIX_TOTAL"_coverage.wig.gz
    if [ $AL_DEBUG != 0 ]; then
        mv "$VAR_OUTPUT_PREFIX1"_preProject.wig "$VAR_OUTPUT_PREFIX1"_preProject_coverage.wig
        mv "$VAR_OUTPUT_PREFIX2"_preProject.wig "$VAR_OUTPUT_PREFIX2"_preProject_coverage.wig
        mv "$VAR_OUTPUT_PREFIX_TOTAL".wig "$VAR_OUTPUT_PREFIX_TOTAL"_coverage.wig
    fi
    
    mergeTwoStrandMethylation "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN1"_preProject.CpG_report.txt "$VAR_OUTPUT_PREFIX1"_preProject.CpG_site_report.txt
    mergeTwoStrandMethylation "$PARAM_BAM_PREFIX"_"$PARAM_STRAIN2"_preProject.CpG_report.txt "$VAR_OUTPUT_PREFIX2"_preProject.CpG_site_report.txt
    
    convertMethylationToWig "$VAR_OUTPUT_PREFIX1"_preProject.CpG_site_report.txt "$VAR_OUTPUT_PREFIX1"_preProject_methyl.wig
    convertMethylationToWig "$VAR_OUTPUT_PREFIX2"_preProject.CpG_site_report.txt "$VAR_OUTPUT_PREFIX2"_preProject_methyl.wig
    
    projectToReferenceGenome "$VAR_OUTPUT_PREFIX1"_preProject_methyl.wig "$PARAM_REFMAP_FILE1" "$VAR_OUTPUT_PREFIX1"_methyl.bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$VAR_OUTPUT_PREFIX1"_methyl.bedGraph "$PARAM_CHROM_SIZES" "$VAR_OUTPUT_PREFIX1"_methyl.bw
    
    projectToReferenceGenome "$VAR_OUTPUT_PREFIX2"_preProject_methyl.wig "$PARAM_REFMAP_FILE2" "$VAR_OUTPUT_PREFIX2"_methyl.bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$VAR_OUTPUT_PREFIX2"_methyl.bedGraph "$PARAM_CHROM_SIZES" "$VAR_OUTPUT_PREFIX2"_methyl.bw
    
    cp "$PARAM_BAM_PREFIX"_total.CpG_report.txt "$VAR_OUTPUT_PREFIX_TOTAL".CpG_report.txt
    mergeTwoStrandMethylation "$VAR_OUTPUT_PREFIX_TOTAL".CpG_report.txt "$VAR_OUTPUT_PREFIX_TOTAL".CpG_site_report.txt
    convertMethylationToBedgraph "$VAR_OUTPUT_PREFIX_TOTAL".CpG_site_report.txt "$VAR_OUTPUT_PREFIX_TOTAL"_methyl.bedGraph
    $AL_BIN_BEDGRAPH_TO_BW "$VAR_OUTPUT_PREFIX_TOTAL"_methyl.bedGraph "$PARAM_CHROM_SIZES" "$VAR_OUTPUT_PREFIX_TOTAL"_methyl.bw

#}
fi
