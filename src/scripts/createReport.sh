#-----------------------------------------------------------#
#			MODULE 5			    #
#-----------------------------------------------------------#	
# generates .tsv data files containing allelic coverage and
# total RPKM values over user-define intervals. These int-
# ervals can be gene exons, gene promoters, known enhancers
# CpG islands, etc
# Requirements: indexed reference genome, interval file in
# gff formats (General Feature Format).
#-----------------------------------------------------------#

#!/bin/bash

pushd `dirname $0` > /dev/null
AL_DIR_TOOLS=`pwd -P` # get the full path to itself
popd > /dev/null

source $AL_DIR_TOOLS/alea.config

##############################################################################
#############   Module 5: statistical analysis
##############################################################################

PARAM_VALID=1
PARAM_SINGLE_READS=1
if [ $AL_USE_CONCATENATED_GENOME = 1 ]; then
    if [ $# -eq 6 ]; then
        PARAM_PREFIX_BAM=$1
	PARAM_STRAIN1=$2
	PARAM_STRAIN2=$3
        PARAM_INTERVALS=$4
	PARAM_MIN_MAPQ=$5
	PARAM_OUTPUT=$6
    else
        PARAM_VALID=0
    fi
else
    PARAM_VALID=0
    fi
fi

if [ $PARAM_VALID = 0 ]; then
    echo "
Usage:
    using concatenated genome method (AL_USE_CONCATENATED_GENOME=1):
        alea createReport <input bam prefix> <strain1> <strain2> <interval file> <minimum MAPQ filter> <output folder>
Options:
    input_bam_prefix  prefix of input bam filenames
		      will be used as basename for all subsequent files in this module
		      
    strain1	      as per previous modules
    strain2	      as per previous modules
    
    intervals         General Feature Format (GFF) used for counting reads
    		      supplied in folder "gff"
		      if using custom gff, please match supplied format
                    
    min MAPQ   	      minimum mapping quality for an aligned read to be kept
		      this will change depending on the aligner used.
		      for BWA, we suggest MAPQ 10
		      for bowtie2, we suggest MAPQ X
		      for Tophat2, we suggest MAPQ X
		      for STAR, we suggest MAPQ 1
		      for Bismark, we suggest MAPQ X

Output:
        
    outputPrefix_analysis.tsv	a table with allelic coverage, total RPKM, parental ratios
				and other statistics for each interval in the GFF file.

Examples:
    (AL_USE_BWA=1)
    alea createReport H3K4me3Liver C57BL6J CAST_EiJ transcriptionStartSites_mm10.gff 10 promoter_statistics
    (AL_USE_STAR=1)
    alea createReport F1hybridLiver C57BL6J CAST_EiJ RefseqGenes_mm10.gff 1 gene_expression_analysis

"
exit 1
fi




function BAM2WIGbedtools {
	PARAM_PREFIX=$1
	PARAM_CHROMOSOME_SIZES=""

	$AL_BIN_SAMTOOLS view -bh -F "$PARAM_FLAG" -q "$PARAM_MINMAPQ" "$PARAM_PREFIX".bam > "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bam
	$AL_BIN_BEDTOOLS genomecov -ibam "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bam -bg -split -scale "$RPM_SCALING_FACTOR" > "$PARAM_PREFIX"l_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bedGraph
	$AL_BIN_BEDGRAPH_TO_BW "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bedGraph "$PARAM_CHROMOSOME_SIZES" "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bw #output this file for viz

        awk 'BEGIN {
                print "track type=wiggle_0"
        }
        NF == 4 {
                print "fixedStep chrom="$1" start="$2+1" step=1 span=1"
                for(i = 0; i < $3-$2; i++) {
                        print $4
                }
        }' "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bedGraph > "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".wig
	bgzip -c "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".wig > "$PARAM_PREFIX".wig.gz
}

BAM2WIGbedtools "$PARAM_PREFIX"_total
BAM2WIGbedtools "$PARAM_BAM_PREFIX"_"$STRAIN1"
BAM2WIGbedtools "$PARAM_BAM_PREFIX"_"$STRAIN2"





function TrackHubGenerate {
	local PARAM_INPUT_PREFIX=$1
	local PARAM_CHROMOSOME_SIZES=""
	PARAM_STRAIN1=""
	PARAM_STRAIN2=""
	local PARAM_GENOME=""
	

 	RPM_SCALING_FACTOR_tmp=`samtools view -c "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bam`
	RPM_SCALING_FACTOR=$(echo "scale=25;1000000/$RPM_SCALING_FACTOR_tmp" | bc)
	echo ""$PARAM_PREFIX" scaling factor: "$RPM_SCALING_FACTOR"" >> "$AL_LOG"/log.txt

	awk -F "\t" -v RPM_SCALE="$RPM_SCALING_FACTOR" 'BEGIN {OFS="\t"; print $0} {
		$4 *= RPM_SCALE
		print $0;}' "$PARAM_PREFIX"_"$STRAIN1".bedGraph > "$PARAM_PREFIX"_"$STRAIN1"_tmp1.bedGraph
	grep -v "type" "$PARAM_PREFIX"_"$STRAIN1"_tmp1.bedGraph > "$PARAM_PREFIX"_"$STRAIN1"_tmp2.bedGraph
	sort -k1,1 -k2,2n "$PARAM_PREFIX"_"$STRAIN1"_tmp2.bedGraph > "$PARAM_PREFIX"_"$STRAIN1"_tmp3.bedGraph
	$AL_BIN_BEDGRAPH_TO_BW "$PARAM_PREFIX"_"$STRAIN1"_tmp3.bedGraph "$PARAM_CHROMOSOME_SIZES" ./Track_Hub/"$PARAM_GENOME"/"$PARAM_PREFIX"_"$STRAIN1".bw

	awk -F "\t" -v RPM_SCALE="$RPM_SCALING_FACTOR" 'BEGIN {OFS="\t"; print $0} {
                $4 *= RPM_SCALE
                print $0;}' "$PARAM_PREFIX"_"$STRAIN2".bedGraph > "$PARAM_PREFIX"_"$STRAIN2"_tmp1.bedGraph
	grep -v "type" "$PARAM_PREFIX"_"$STRAIN2"_tmp1.bedGraph > "$PARAM_PREFIX"_"$STRAIN2"_tmp2.bedGraph
	sort -k1,1 -k2,2n "$PARAM_PREFIX"_"$STRAIN2"_tmp2.bedGraph > "$PARAM_PREFIX"_"$STRAIN2"_tmp3.bedGraph
	$AL_BIN_BEDGRAPH_TO_BW "$PARAM_PREFIX"_"$STRAIN2"_tmp3.bedGraph "$PARAM_CHROMOSOME_SIZES" ./Track_Hub/"$PARAM_GENOME"/"$PARAM_PREFIX"_"$STRAIN2".bw

	awk -F "\t" -v RPM_SCALE="$RPM_SCALING_FACTOR" 'BEGIN {OFS="\t"; print $0} {
                $4 *= RPM_SCALE
                print $0;}' "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ".bedGraph > "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp1.bedGraph
	grep -v "type" "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp1.bedGraph > "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp2.bedGraph
	sort -k1,1 -k2,2n "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp2.bedGraph > "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp3.bedGraph
	$AL_BIN_BEDGRAPH_TO_BW "$PARAM_PREFIX"_F"$PARAM_FLAG"_q"$PARAM_MINMAPQ"_tmp3.bedGraph "$PARAM_CHROMOSOME_SIZES" ./Track_Hub/"$PARAM_GENOME"/"$PARAM_PREFIX"_total.bw


	printf "genome "$PARAM_GENOME"\ntrackDb "$PARAM_GENOME"/trackDb.txt" > ./Track_Hub/genomes.txt
	printf "hub <name>\nshortLabel <short name>\nlongLabel <Hub to dispaly data at UCSC>\ngenomesFile genomes.txt\nemail <email>" > ./Track_Hub/hub.txt
	printf "track %s\ncontainer multiWig\nshortLabel %s\nlongLabel %s\ntype bigWig\nvisibility full\nmaxHeightPixels 150:60:32\nconfigurable on\nautoScale on\naggregate transparentOverlay\nshowSubtrackColorOnUi on\npriority 1.0\n\n" "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total.bw | tee -a ./Track_Hub/"$PARAM_GENOME"/trackDb.txt
	printf "\ttrack %s\n\tparent %s\n\tshortLabel %s\n\tlongLabel %s\n\ttype bigWig\n\tbigDataUrl %s\n\tcolor 215,215,215\n\taltColor 225,225,225\n\tautoScale on\n\n" "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total "$PARAM_PREFIX"_total.bw | tee -a ./Track_Hub/"$PARAM_GENOME"/trackDb.txt
	printf "\ttrack %s\n\tparent %s\n\tshortLabel %s\n\tlongLabel %s\n\ttype bigWig\n\tbigDataUrl %s\n\tcolor 215,215,215\n\taltColor 225,225,225\n\tautoScale on\n\n" "$PARAM_PREFIX"_"$STRAIN1" "$PARAM_PREFIX"_"$STRAIN1" "$PARAM_PREFIX"_"$STRAIN1" "$PARAM_PREFIX"_"$STRAIN1" "$PARAM_PREFIX"_"$STRAIN1".bw | tee -a ./Track_Hub/"$PARAM_GENOME"/trackDb.txt
	printf "\ttrack %s\n\tparent %s\n\tshortLabel %s\n\tlongLabel %s\n\ttype bigWig\n\tbigDataUrl %s\n\tcolor 215,215,215\n\taltColor 225,225,225\n\tautoScale on\n\n" "$PARAM_PREFIX"_"$STRAIN2" "$PARAM_PREFIX"_"$STRAIN2" "$PARAM_PREFIX"_"$STRAIN2" "$PARAM_PREFIX"_"$STRAIN2" "$PARAM_PREFIX"_"$STRAIN2".bw | tee -a ./Track_Hub/"$PARAM_GENOME"/trackDb.txt
	$AL_BIN_HUBCHECK ./Track_Hub/hub.txt
}





function generateRPKM {
	$AL_BIN_PYTHON $AL_BIN_RPKMCOUNT -i "$PARAM_PREFIX".bam -r "$PARAM_INTERVALS" -o "$PARAM_PREFIX" -q "$PARAM_MINMAPQ" -e
}

function generateRPKMcustom {
#input gff file
#input bedGraph files from 1) bedtools genomecov (total.bedgraph) and 2) alea project (strain1.bedgraph strain2.bedgraph)
#convert to smart format: unique "genes" i.e. no isoforms (done in Python) BY EXON
#bedtools intersect the unique exon and bedgraph files
#using geneName value to merge (SUM) counts over all exons from the same gene
#divide the total.bedgraph column by the calculated mRNA size 
#report the strain1.bedgraph and strain2.bedgraph columns as COVERAGE
#calculate final column: parental_skew / parental_ratio / bias (strain2/(strain1+2)
}

	





