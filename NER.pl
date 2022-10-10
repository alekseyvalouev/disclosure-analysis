#!/usr/bin/perl -w
#use strict;
use warnings;

#The purpose of this program is to count NER entities for patient comments

#File and folder names to define
my $outputcsv='/pine/scr/l/s/lstice/patient_comment_text_measuresLINUX.csv';       #CSV file where I will save the text based measures to
my $cleanfolder='/pine/scr/l/s/lstice/Cleaned_Readable_Comments';#folder which includes cleaned comments that can actually be read, that were the version of the comments used to calculate phrase counts, etc

#list of subfolders to analyze
my @hash_subfolders = ('accesscomments', 'careprovidercomments', 'labcomments', 'movingthroughvisitcomments', 'nurseassistantcomments', 'overallcomments', 'personalissuescomments', 'registrationcomments');    


#inputs to run NER tool (named entity recognizer)
my $ner_folder='/nas/longleaf/home/lstice/stanford-ner-2018-10-16'; 	#folder where Stanford NER tool is installed
my $classifier='english.muc.7class.distsim.crf.ser.gz';                 #name of the classifier file that you are using (e.g. english.all.3class.distsim.crf.ser.gz identifies 3 types of entities, while english.muc.7class.distsim.crf.ser.gz identifies 7, as in the Ole-Kristian Hope Specificity paper)
my $mem='600m'; #this sets the maximum memory that the NER tool is allowed to take (i.e. 600m lets it use 600 mb of RAM)
#my $tempdir='/pine/scr/l/s/lstice/Temp';#directory where I will save temporary files that will be input to Stanford NER tool, since it requires me to call files into the program, not text strings
my $tempdir='/pine/scr/l/s/lstice/Temp';#directory where I will save temporary files that will be input to Stanford NER tool, since it requires me to call files into the program, not text strings

#Modules I will use
use Text::CSV;
use File::Slurp;


#############################################
#   Create CSV Output File using Text::CSV  #
#############################################
#my @rows1;
my $csv1 = Text::CSV->new ( { binary => 1, eol => "\n", auto_diag => 1 } )  #choose some recommended Text::CSV settings
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
open(my $mycsv, ">>", $outputcsv) or die "$outputcsv: $!";#open csv file you will write to

#name the columns of the csv you will generate
my @labels=('file_id', 'entity_count');
$csv1->print ($mycsv, [@labels]);




### Loop through all the files in the comments folder (including all subdirectories)###
foreach my $subfolder (@hash_subfolders) {
    opendir my $dir1, "$cleanfolder/$subfolder" or die $!;
    while (my $file = readdir ($dir1)){
        next unless (-f "$cleanfolder/$subfolder/$file");#we only want files
         
        #Use File::Slurp to read the entire file into a string
        my $text = read_file("$cleanfolder/$subfolder/$file");
          
   
        ########################################################################################################
        #		Use the Stanford NER Tool to identify named entities
        ########################################################################################################
        #because the Stanford NER tool requires a file as input (instead of a string), I'll just save a temporary version of the comment in a file using Slurp in order to analyze it
        my $entity_count=0;
        
        my $input_file = "$cleanfolder/$subfolder/$file"; #define file to analyze (could also change program for this to be text in a variable)
        #Change folders to the folder where the Stanford NER tool is installed--only when this is the working directory can you run the NER commands below
        chdir($ner_folder) or die "$!";
           
        #version originally used for Mark/Travis project
        my $tagged_entities=`java -mx$mem -cp "*:lib/*" edu.stanford.nlp.ie.crf.CRFClassifier -loadClassifier classifiers/$classifier -textFile $input_file -outputFormat tabbedEntities 2> /dev/null`; #puts error output into "black hole": 2> /dev/null

        #Format of the NER output: 1st column is entity names, 2nd column is entity type, and 3rd column is all other text in between recognized entities
        my @lines = split /\n/, $tagged_entities; #split output into lines
    
        foreach my $line (@lines) {
            #no warnings; #disable warnings in this part of the code so that when the first 2 columns are output are undefined, there isn't any warning output (that could get pretty bulky)
            my @columns=split /\t/, $line;
            if (($columns[0] eq '') or ($columns[1] eq '')) { #if either of the first 2 columns are empty, it means no entity is identified in that row
                next;
            } else { #if entity is identified
                $entity_count++; #Add 1 to the total running count of entities
            }
        }
        #use warnings;
      
        
    #Now print the variables to a CSV file
    my @columns=($file, $entity_count);
    $csv1->print ($mycsv, [@columns]);

    }#end of loop through comment subfolder
    closedir $dir1;
}


close $mycsv or die "$!";#close output csv