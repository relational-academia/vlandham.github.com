---
layout: post
title: "RNA-seq: Comparing Similar Libraries"
categories:
- bioinfo
---

This task involves comparing RNA-seq data generated from 3 similar libraries. The difference between the libraries is the number of cells collected to be used in the construction of the libraries. This dataset contains 2 samples each from libraries constructed from 1,000, 10,000 and 30,000 mouse bone marrow derived hematopoietic stem cells.

The idea, as it was explained to me, is to see if researchers can get away with small cell numbers when constructing libraries for use with RNA-seq. Specifically, what do you loose in your data as you use lower and lower cell numbers.

Not a very concrete question, but perhaps a good one all the same.

Analysis Goals
--------------

Discussing with other analysts about what to do, Here are some questions I’d like to answer during analysis:

-   What is the percent FPKM change as we move from higher number of cells to lower number?
-   How does gene coverage change from high to low?
    -   Does coverage overall go down with fewer cell numbers?
    -   Are there spots in the exome that are lacking in the low cell number samples that have coverage in the higher cell number samples?
-   How do the numbers of multi-reads change?
    -   Multi-reads are those reads that map to multiple places on the genome. Does the percentage of the total number of aligned reads that are considered multi-reads increase in low cell number samples?
-   Does the absolute number of genes covered at all by the data change?
    -   Here we would like to see if more cells provide more information in terms of the number of genes found in the data. We might expect that the lower cell numbers would have more genes missing from the RNA-seq data, due to lower coverage.
    -   Information could be graphed with cell numbers on x-axis, and on the y-axis, show the percentage of the total number of genes of the organism that were detected in the data.

Tools Used
----------

It is my attempt to get a cohesive picture of each of these datasets, so as to better understand what is different about them. So I used a number of tools that can provide various details about the dataset, along with the normal alignment and RPKM tools.

-   [TopHat](http://tophat.cbcb.umd.edu/manual.html) v1.3.1
-   [Cufflinks](http://cufflinks.cbcb.umd.edu/tutorial.html) v1.0.3
-   [Samtools](http://samtools.sourceforge.net) v0.1.16
-   [picard](http://picard.sourceforge.net/) v1.49
-   [BEDTools](http://code.google.com/p/bedtools/) v2.12
-   [fastqc](http://www.bioinformatics.bbsrc.ac.uk/projects/fastqc/) v0.9.3
-   [FASTX-Toolkit](http://hannonlab.cshl.edu/fastx_toolkit/)

Pipeline
--------

The initial process is similar to my previous RNA-seq analysis. However after alignment and RPKM values are determined, we need to do a lot more analysis to see patterns between datasets

1.  fastqc for initial read quality
2.  Align with TopHat
3.  Cufflinks for RPKM values
4.  picard for alignment metrics
5.  BEDTools to discover gene coverage

I’ll avoid explaining all the parameters again for the tools used, but go over how they were used in the analysis.

### Removing Duplicates

As before, no duplication removal was performed. It seems that this would remove information that could be valuable to this particular analysis.

### Trimming

The initial look at the data using fastqc indicated serious degradation of the quality of some of the samples’ reads after 25bp. This is unfortunate, and perhaps indicates that the analysis with not be as fruitful as one would like. However, the analysis must go on! FastX was used to trim the samples from all libraries to 25bp. This deals with the bad quality of some of the reads, and prevents biases that would be present for longer reads, if all of the samples were not trimmed.

Here’s how Fastx was called:

``` terminal
zcat sequence.fastq.gz | fastx_trimmer -f 1 -l 25 -z -o sequence.trim.fastq.gz -Q33
```

As we are using CASAVA 1.8, everything comes compressed. So `zcat` is used to decompress on the fly. The `-z` option re-compresses the trimmed reads, so we can keep using `.gz` files. The `-Q33` option is required to indicate the type of quality score used. CASAVA 1.8 switches to using the standard Sanger 33-offset-based quality scores. At the time FastX couldn’t figure this out, so you have to tell it. This is a undocumented parameter that I found out about from [this SEQAnswers post](http://seqanswers.com/forums/showthread.php?t=7596) .

### TopHat

Most of the defaults were used. Because of the short reads, Tophat was complaining that the `--segment-length` parameter should be made to be equal to roughly half the read length. So that’s what I did. Also, The gene model annotation file (`.gtf`) was provided so that it wouldn’t try to figure out junctions de-novo.

``` terminal
tophat -G /n/data1/genomes/bowtie-index/mm9/Ens_63/mm9.Ens_63.gtf -p 4 \
--segment-length 12  -o tophat /n/data1/genomes/bowtie-index/mm9/mm9 sequence.trim.fastq.gz
```

Where the `-G` flag provides the gene model annotation, and the second to last parameter is the path to the bowtie index files.

### Cufflinks

Similar to TopHat, most of the defaults were used:

``` terminal
cufflinks -p 4 -o cufflinks -G /path/to/GTF/file.gtf accepted_hits.bam
```

Where the input BAM file for each sample was the output produced by TopHat.

### picard

I wanted to see what information picard’s **CollectAlignmentSummaryMetrics** tool would provide, so I ran this on all the bam files. Picard and GATK can be particular about the order of the bam files. So, first I used picard’s **AddOrReplaceReadGroups** and it’s **ReorderSam** to get the bam files in a state where they would be taken by picard without dying:

``` terminal
java -jar picard/AddOrReplaceReadGroups.jar INPUT=accepted_hits.bam OUTPUT=accepted_hits.group.bam \
VALIDATION_STRINGENCY=LENIENT SORT_ORDER=coordinate RGLB=1 RGPL=illumina RGPU=1 RGSM=name

java -jar picard/ReorderSam.jar INPUT=accepted_hits.group.bam OUTPUT=accepted_hits.group.reorder.bam \
VALIDATION_STRINGENCY=LENIENT REFERENCE=mm9.fa CREATE_INDEX=true

java -jar picard/CollectAlignmentSummaryMetrics.jar INPUT=accepted_hits.group.reorder.bam \
OUTPUT=alignment_summary.out.txt REFERENCE_SEQUENCE=mm9.fa
```

All that work, and what did I get? Not much. This tool seems like it could be more useful for paired-end data with reads that don’t pass filter in it. It does provide the total number of reads in the bam file, but this would be easy to acquire by other means.

### BEDTools

BEDTools has a **coverageBed** program that I thought could help shed light on how well the various libraries covered each gene. I used a bed file we have containing exons to provide it the locations of the exons.

<div class="box">
**Note on Exon Bed File**
There are some particulars about this bed file that other analysts helped me understand and generate. First, There are a number of exons that overlap one another. Keeping them all would inflate the perceived coverage of those areas where a lot of overlapping exons existed. So, BEDTools mergeBed tool can be used to squash these overlapping exons. However, then you hit another problem where overlapping exons that belong to separate genes will get squashed together. We don’t want this to happen, as we are also trying to show the number of genes hit by the data. So, the solution we have here is to break up the bedfile based on genes, then squash exons at a per-gene level, and then merging the exons back together. Not sure if there is an easier way…

</div>
``` terminal
coverageBed -s -split -abam ./accepted_hits.bam -b ./mm9.Ens_63.exons.bed > ./coverageBed.out.txt
```

Analysis
--------

### Coverage

As mentioned above, I used BEDTools to get coverage information of the exons covered for each sample.

The command executed should provide an output file that contains a line for each line in the input `.bed` file. Each output line starts with the corresponding bed file line and then ends with a few more tab-delimited fields:

-   Number of reads in A (the bam file) that overlap the B (the bed file) line’s interval by at least one base pair.
-   Number of bases in B that have some coverage from A.
-   The length of the interval of B
-   The fraction of bases in B that have some coverage from A.

From this run, an example would be:

``` terminal
chr1    59768115        59768968        exon281764      1       +       172     342     853     0.4009379
```

So, for this particular exon, we can see that of the 853 bases in the exon, 342 of them were overlapped by one or more of 172 reads from the bam file. This means about 40% of the exon was covered by the reads, with a maximum coverage of 172… right?

Further analysis of this output was performed with R. Eventually, I extracted from these bed files:

-   Total number of exons that were covered by some amount of reads from the sample.
-   Number of exons per chromosome that were covered.
-   Percentage of all exons that were covered by sample (both for the whole sample and by chromosome).
-   Total number of unique genes that were covered by some reads.
    -   Found by getting the unique gene names from the exons list.
-   Percentage of unique genes covered by reads.

I’m unsure as to what a meaningful criteria is for the “some amount of reads” coverage stipulation. Should it be at least X number of bases covered by reads, Y number of reads on the exon, or Z percentage of the exon covered?

With the coverageBed output, I have access to all three options. The trends look to stay the same, regardless of the selection - but the specific numbers change as you would expect.

I analyzed each sample separately, even though there was two samples per library. The differences were enough to be potentially interesting.

I also then combined the coverage datasets per library to show a more aggregated form of the data.

### Expression Values

Next, I turned to the FPKM values generated from Cufflinks to see if differences could be seen in the various cell numbers.

First I looked at the covariance between the samples to see if samples from the same library were similar, and if the expression values from different cell numbers looked different. I borrowed code from another analyst that displays covariances between samples as a matrix of color squares, where the color indicates the correlation.
