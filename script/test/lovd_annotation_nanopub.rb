require 'rdf'
require 'logger'
require 'slop'
require_relative 'lovd_converter'
#require 'rdf-agraph'

# Create nanopublication for LOVD dataset.
#
# Input file format: .tsv
# File columns : --TO DO--
class LOVD_Nanopub_Converter < RDF_File_Converter
  
  # URIs string
  $baseURI = 'http://www.rdf.biosemantics.org/nanopubs/lovd/whole_genome/'
  $resourceURI = 'http://rdf.biosemantics.org/resource/lovd/whole_genome/'

  # Define some useful RDF vocabularies.(Note: Define subclass RDF vocabularies here)
  FOAF = RDF::FOAF
  DC = RDF::DC
  RDFS = RDF::RDFS
  XSD = RDF::XSD
  RSA = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/referencesequence#')
  HG19 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/hg19#')
  PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
  OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
  PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
  NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')
  VO = RDF::Vocabulary.new('http://hgvs.org/ontology/Variation#')  
  SNP = RDF::Vocabulary.new('http://www.loria.fr/~coulet/ontology/snpontology/version1.5/snpontology_full.owl#')
  BIOPAX = RDF::Vocabulary.new('http://www.biopax.org/release/biopax-level3.owl/')
  ESG = RDF::Vocabulary.new('http://dataportal.ucar.edu/schemas/esg.owl#')
  LDREFSEQ = RDF::Vocabulary.new('http://linkedlifedata.com/resource/entrezgene/refseq/')
  $base = RDF::Vocabulary.new($baseURI)




  def initialize

    # useful stuff for serializing graph.
    prefixes = {
        :dcterms => DC,
        :np => NP,
        :rdf => RDF,
        :pav => PAV,
        :xsd => XSD,
        :rdfs => RDFS,
        :prov => PROV,
        :vo => VO,
        :rsa => RSA,
        :snp => SNP,
        :biopax => BIOPAX,
        :esg => ESG,
        :ldrefseq => LDREFSEQ,
        nil => $base
    }

    optionsTrancript = Slop.parse(:help => true) do      
      on :source_url=, 'Source of the dataset'
    end

    optionsTrancript.to_hash


    @npVersion = 1.0
    @transcriptID = nil
    @chromosome = nil
    @sourcePage = optionsTrancript[:source_url]
    @variantTemplate = nil
    @variantTechnique = nil
    @variantPubMedID = nil
    #@lovdData = RDF::Vocabulary.new("http://www.rdf.biosemantics.org/nanopubs/lovd/data/")


    super(RDF, NP, prefixes)

  end
  protected
  def get_options

    options = Slop.parse(:help => true) do
      banner "ruby lovd_nanopub_converter.rb [options]\n"
      #on :base_url=, :default => "http://www.rdf.biosemantics.org/nanopubs/lovd/02/gva/"
      #on :base_url=, :default => "http://www.rdf.biosemantics.org/nanopubs/lovd/02/tva/"
      #on :base_url=, :default => "http://www.rdf.biosemantics.org/nanopubs/lovd/02/#{optionsGene[:gene]}/tva/"
    end

    super.merge(options)
  end


  def convert_header_row(row)
    # do nothing
  end

  def convert_row_api(geneRow, variantRow)
    
    
    puts "Row = #{variantRow}"
    puts "geneRow = #{geneRow}"

    @variantTemplate = nil
    @variantTechnique = nil
    @variantPubMedID = nil

    tokensVariant = variantRow.split("\t")
    tokensGene = geneRow.split("\t")
    
    # Transcript ID
    @transcriptID = tokensVariant[0].gsub(" ","")
    # Variant database ID (This should be unique for the variant on same build)
    variantDBId = tokensVariant[1].gsub(" ","")
    #DNA change
    dnaChange =  tokensVariant[2].gsub(" ","")
    #genomic change
    genomicChange =  tokensVariant[3].gsub(" ","")
    # HGVSDescription of the variant
    hgvsDescription = "#{@transcriptID}:#{dnaChange}"
    # Genomic region(Start_End)
    #gPos = tokens[2].gsub(" ","")
    # Template used for the variant analysis DNA/RNA
    @variantTemplate = tokensVariant[3].gsub(" ","")
    # Technique used for the variant analysis
    @variantTechnique = tokensVariant[5].gsub(" ","")
    # Pubmed ID
    @variantPubMedID = tokensVariant[6].gsub(" ","")    
    # Chromosome number
    @chromosome = tokensGene[2].gsub(" ","")
    # Gene symbol
    @gene = tokensGene[1].gsub(" ","")

    if (variantDBId == '' || variantDBId == nil)
      @logger.info("row #{@row_index.to_s} has no DB id. skipped. #{variantDBId}")
      return

    else

      # To remove extra whitespace.
      if (variantDBId[variantDBId.length-1] == ' ')
        variantDBId = variantDBId.gsub(/\s+/, "")
      end


      @row_index += 1
      #puts variantDBId

      if (genomicChange == '-NA-' || variantDBId == nil || genomicChange == '-')
        @logger.info("row #{@row_index.to_s} has no g.region. skipped. #{variantDBId}")
        return
      else
        createGenomicVariantAnnotation(genomicChange, variantDBId, @chromosome)
        #createTranscriptVariantAnnotation(dnaChange, variantDBId)
      end

    end

  end
  
  
  def convert_row(variantRow)

    @variantTemplate = nil
    @variantTechnique = nil
    @variantPubMedID = nil

    tokens = variantRow.split("\t")


    # Variant database ID (This should be unique for the variant on same build)
    variantDBId = tokens[1].gsub(" ","")
    #DNA change
    dnaChange =  tokens[2].gsub(" ","")
    #genomic change
    genomicChange =  tokens[3].gsub(" ","")
    # HGVSDescription of the variant
    hgvsDescription = "#{@transcriptID}:#{dnaChange}"
    # Genomic region(Start_End)
    #gPos = tokens[2].gsub(" ","")
    # Template used for the variant analysis DNA/RNA
    @variantTemplate = token4[3].gsub(" ","")
    # Technique used for the variant analysis
    @variantTechnique = tokens[5].gsub(" ","")
    # Pubmed ID
    @variantPubMedID = tokens[6].gsub(" ","")

    #puts "DB-Id = #{variantDBId} "


    if (variantDBId == '' || variantDBId == nil)
      @logger.info("row #{@row_index.to_s} has no DB id. skipped. #{variantDBId}")
      return

    else

      # To remove extra whitespace.
      if (variantDBId[variantDBId.length-1] == ' ')
        variantDBId = variantDBId.gsub(/\s+/, "")
      end


      @row_index += 1
      #puts variantDBId

      if (genomicChange == '-NA-' || variantDBId == nil || genomicChange == '-')
        @logger.info("row #{@row_index.to_s} has no g.region. skipped. #{variantDBId}")
        return
      else
        createGenomicVariantAnnotation(genomicChange, variantDBId, @chromosome)
        #createTranscriptVariantAnnotation(dnaChange, variantDBId)
      end

    end

  end


  protected
  def createGenomicVariantAnnotation(genomicChange, dbID, chromosome)

    gStart = -1
    gEnd = -1

    #puts variant

    if(genomicChange.include? "_")
      gData = genomicChange.split("_")
      gStart = gData[0].gsub(/[^0-9]/i, '').to_i

      # To remove extra numbers (eg. g.71891572_71891573ins24)
      gEndStr = gData[1].gsub(/[^a-z]/i, '')
      gEndData = gData[1].split(gEndStr)

      gEnd = gEndData[0].gsub(/[^0-9]/i, '').to_i
    else
      gStart = genomicChange.gsub(/[^0-9]/i, '').to_i
      gEnd = gStart

    end    
        
    # setup nanopub
    nanopub = RDF::URI.new("#{$baseURI}#{@gene}_genomic_variant_#{@row_index.to_s}")
    assertion = RDF::URI.new("#{$baseURI}#{@gene}_genomic_variant_#{@row_index.to_s}#assertion")
    provenance = RDF::URI.new("#{$baseURI}#{@gene}_genomic_variant_#{@row_index.to_s}#provenance")
    publication_info = RDF::URI.new("#{$baseURI}#{@gene}_genomic_variant_#{@row_index.to_s}#publicationInfo")

    # main graph
    create_main_graph(nanopub, assertion, provenance, publication_info)

    # assertion graph
    variant = RDF::URI.new("#{$resourceURI}#{@gene}_variant_#{@row_index.to_s}") 
    region = RDF::URI.new("#{$resourceURI}#{@gene}_genomic_region_#{@row_index.to_s}")
    genomicAnnotation = RDF::URI.new("#{$resourceURI}#{@gene}_genomic_variant_annotation_#{@row_index.to_s}")
    #orientation = RSO.reverse


    save(assertion, [
        [variant, RSA['hasAnnotation'], genomicAnnotation],
        [genomicAnnotation, RDF.type, RSA['GenomeVariationAnnotation']],
        [genomicAnnotation, RSA['mapsTo'], region],
        [genomicAnnotation,
         RDF::URI.new("http://glycomics.ccrc.uga.edu/ontologies/GlycO#has_identifier"),
         RDF::Literal.new(genomicChange, :datatype => XSD.string)],
        [region, RDF.type, RSA['Region']],
        [region, RSA['regionOf'], HG19[chromosome]],
        [region, RSA['start'], RDF::Literal.new(gStart, :datatype => XSD.int)],
        [region, RSA['end'], RDF::Literal.new(gEnd, :datatype => XSD.int)]
    ])

    # provenance graph
    create_provenance(assertion, provenance)
    # publication info graph
    create_publication_info(publication_info, nanopub)

  end



  protected
  def createTranscriptVariantAnnotation(dnaChange, dbID)


    # setup nanopub
    nanopub = RDF::Vocabulary.new(@base[@row_index.to_s.rjust(6, '0')])
    assertion = nanopub['#assertion']
    provenance = nanopub['#provenance']
    publication_info = nanopub['#publicationInfo']

    # main graph
    create_main_graph(nanopub, assertion, provenance, publication_info)

    # assertion graph
    variant = @lovdData["#{@row_index}variant_#{dbID}"]
    region = @lovdData["#{@row_index}transcript_region_#{dbID}"]
    transcriptAnnotation = @lovdData["#{@row_index}transcript_variant_annotation_#{dbID}"]
    #orientation = RSO.reverse


    save(assertion, [
        [variant, RSA['hasAnnotation'], transcriptAnnotation],
        [transcriptAnnotation, RDF.type, RSA['TranscriptVariationAnnotation']],
        [transcriptAnnotation, RSA['mapsTo'], region],
        [transcriptAnnotation,
         RDF::URI.new("http://glycomics.ccrc.uga.edu/ontologies/GlycO#has_identifier"),
         dnaChange],
        [region, RDF.type, RSA['Region']],
        #[region, RSA['regionOf'], RDF::URI.new("http://bio2rdf.org/refseq:#{@transcriptID}")]
        [region, RSA['regionOf'], RDF::URI.new("http://linkedlifedata.com/resource/entrezgene/refseq/#{@transcriptID}")]
    ])

    # provenance graph
    create_provenance(assertion, provenance)
    # publication info graph
    create_publication_info(publication_info, nanopub)

  end



  protected
  def createGenomicAndTranscriptVariantAnnotation(genomicChange, dbID, gPos, chromosome)

    gStart = -1
    gEnd = -1

    #puts variant

    if(gPos.include? "_")
      gData = gPos.split("_")
      gStart = gData[0].gsub(/[^0-9]/i, '').to_i

      # To remove extra numbers (eg. g.71891572_71891573ins24)
      gEndStr = gData[1].gsub(/[^a-z]/i, '')
      gEndData = gData[1].split(gEndStr)

      gEnd = gEndData[0].gsub(/[^0-9]/i, '').to_i
    else
      gStart = gPos.gsub(/[^0-9]/i, '').to_i
      gEnd = gStart

    end


    # setup nanopub
    nanopub = RDF::Vocabulary.new(@base[@row_index.to_s.rjust(6, '0')])
    assertion = nanopub['#assertion']
    provenance = nanopub['#provenance']
    publication_info = nanopub['#publicationInfo']

    # main graph
    create_main_graph(nanopub, assertion, provenance, publication_info)

    # assertion graph
    variant = @lovdData["#{@row_index}variant_#{dbID}"]
    region1 = @lovdData["#{@row_index}genomic_region_#{dbID}"]
    genomicAnnotation = @lovdData["#{@row_index}genomic_variant_annotation_#{dbID}"]
    region2 = @lovdData["#{@row_index}transcript_region_#{dbID}"]
    transcriptAnnotation = @lovdData["#{@row_index}transcript_variant_annotation_#{dbID}"]
    #orientation = RSO.reverse


    save(assertion, [
        [variant, RSA.hasAnnotation, genomicAnnotation],
        [genomicAnnotation, RDF.type, RSA['GenomeVariationAnnotation']],
        [genomicAnnotation, RSA.mapsTo, region1],
        [genomicAnnotation,
         RDF::URI.new("http://glycomics.ccrc.uga.edu/ontologies/GlycO#has_identifier"),
         genomicChange],
        [region1, RDF.type, RSA.Region],
        [region1, RSA.regionOf, HG19[chromosome]],
        [region1, RSA.start, RDF::Literal.new(gStart, :datatype => XSD.int)],
        [region1, RSA.end, RDF::Literal.new(gEnd, :datatype => XSD.int)],

        [variant, RSA.hasAnnotation, transcriptAnnotation],
        [transcriptAnnotation, RDF.type, RSA['TranscriptVariationAnnotation']],
        [transcriptAnnotation, RSA.mapsTo, region2],
        [transcriptAnnotation,
         RDF::URI.new("http://glycomics.ccrc.uga.edu/ontologies/GlycO#has_identifier"),
         dnaChange],
        [region2, RDF.type, RSA.Region],
        #[region2, RSA.regionOf, RDF::URI.new("http://bio2rdf.org/refseq:#{@transcriptID}")]
        [region, RSA['regionOf'], RDF::URI.new("http://linkedlifedata.com/resource/entrezgene/refseq/#{@transcriptID}")]
    ])

    # provenance graph
    create_provenance(assertion, provenance)
    # publication info graph
    create_publication_info(publication_info, nanopub)

  end


  def create_provenance(assertion, provenance)
    save(provenance, [
        [assertion, PROV.wasDerivedFrom, RDF::URI.new(@sourcePage)]
    ])

    # Save pubmed Id
    if (@variantPubMedID != nil && @variantPubMedID !='-NA-' && @variantPubMedID !='-')

      pubMedData = @variantPubMedID.split(",")
      pubMedData.each { |pID|
        save(provenance,[
            [assertion, ESG.hasReference, RDF::URI.new("http://bio2rdf.org/pubmed:#{pID}")]
        ])
      }
    end


    # Save template
    if (@variantTemplate != nil && @variantTemplate !='-NA-' && @variantTemplate !='-')

      templates = @variantTemplate.split(",")
      templates.each { |template|

        if (template == 'DNA' || template =='dna' || template == 'Dna')
          save(provenance,[[assertion, LOVD['detected_in'], BIOPAX['Dna']]])
        else if (template == 'RNA' || template =='rna' || template == 'Rna')
               save(provenance,[[assertion, LOVD['detected_in'], BIOPAX['Rna']]])

             end
        end
      }
    end


=begin
    # Save template
    if (@variantTemplate != nil && @variantTemplate !='-NA-')

      templates = @variantTemplate.split(",")
      templates.each { |template|

        if (template == 'DNA' || template =='dna' || template = 'Dna')
          save(provenance,[[assertion, BIOPAX['template'], BIOPAX['Dna']]])
        else if (template == 'RNA' || template =='rna' || template = 'Rna')
          save(provenance,[[assertion, BIOPAX['template'], BIOPAX['Rna']]])
             end
        end
      }
    end
=end

  end

  def create_publication_info(publication_info, nanopub)
    save(publication_info, [
        [nanopub, DC.rights, RDF::URI.new('http://www.creativecommons.org/licenses/by/3.0/')],
        [nanopub, DC.rightsHolder, RDF::URI.new('http://www.biosemantics.org')],
        # J-7843-2013 = Rajaram Kaliyaperumal
        [nanopub, PAV.authoredBy, RDF::URI.new('http://www.researcherid.com/rid/J-7843-2013')],
        # B-5852-2012 = Zuotian Tatum
        [nanopub, PAV.authoredBy, RDF::URI.new('http://www.researcherid.com/rid/B-5852-2012')],
        # J-7843-2013 = Rajaram Kaliyaperumal
        [nanopub, PAV.createdBy, RDF::URI.new('http://www.researcherid.com/rid/J-7843-2013')],
        # E-7370-2012 = Mark Thompson
        [nanopub, PAV.createdBy, RDF::URI.new('http://www.researcherid.com/rid/E-7370-2012')],
        [nanopub, PAV.curatedBy, RDF::Literal.new('Johan den Dunnen', :datatype => XSD.string)],
        [nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)],
        [nanopub, DC.hasVersion, RDF::Literal.new(@npVersion.to_f, :datatype => RDF::XSD.double)]
    ])

  end

end


# do the work
LOVD_Nanopub_Converter.new.convertFromAPI