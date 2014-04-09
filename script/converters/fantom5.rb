# Example arguments (Shell script):
# ruby fantom5.rb --input /home/raja/fantom5/fantom5DS.txt --output /home/raja/fantom5/fantom5-np/fantom5 --subtype ff_expressions --username raja --password raja --catalog system --repository test --host localhost --port 10035
#
# Example arguments (Rubymine):
# '-help --input /home/raja/fantom5/fantom5DS.txt --output /home/raja/fantom5/fantom5-np/fantom5 --subtype ff_expressions --username raja --password raja --catalog system --repository test --host localhost --port 10035'

require 'rdf'
require 'slop'
require_relative 'converter'

class Fantom5_Nanopub_Converter < RDF_File_Converter

  # Define some useful RDF vocabularies.(Note: Define subclass RDF vocabularies here)
  FOAF = RDF::FOAF
  DC = RDF::DC
  RDFS = RDF::RDFS
  XSD = RDF::XSD
  RSO = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/referencesequence#')
  HG19 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/hg19#')
  SO = RDF::Vocabulary.new('http://purl.org/obo/owl/SO#')
  PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
  OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
  PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
  NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')
  SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')
  FF = RDF::Vocabulary.new('http://purl.obolibrary.org/obo/FF_')
  IAO = RDF::Vocabulary.new('http://purl.obolibrary.org/obo/')
  FFU = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/fantom5Units#')
  FANTOM5 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/riken/fantom5/data#')
  $base = RDF::Vocabulary.new('http://rdf.biosemantics.org/nanopubs/riken/fantom5/')


  def initialize

    # useful stuff for serializing graph.
    prefixes = {
        :dcterms => DC,
        :np => NP,
        :rdf => RDF,
        #:sio => SIO,
        :pav => PAV,
        :xsd => XSD,
        :rdfs => RDFS,
        :prov => PROV,
        :iao => IAO,
        :so => SO,
        :rso => RSO,
        nil => $base
    }

    # read all cell types
    $ffont = File.read('ffont.rb').split(", ")

    $npVersion = 1.0

    super(RDF, NP, prefixes)

  end

  @@AnnotationSignChars = '+-'

  def convert_header_row(row)
    # do nothing
    # ignore summary rows
  end

  def convert_row(row)

    @row_index += 1
    annotation, shortDesc, description, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot, *samples = row.split("\t")

    case @options[:subtype]
      when 'cage_clusters'
        create_class1_nanopub(annotation)
      when 'gene_associations'
        create_class2_nanopub(annotation, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot)
      when 'ff_expressions'
        create_class3_nanopub(annotation, samples)
    end

  end

  protected
  def get_options
    options = Slop.parse(:help => true) do
      banner "ruby Fantom5_Nanopub_Converter.rb [options]\n"
      on :base_url=, :default => 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/'
      on :subtype=, 'nanopub subtype, choose from [cage_clusters, gene_associations, ff_expressions]', :default => 'cage_clusters'
      on :celltype=, 'cell type for type 3 nanopub'
    end

    super.merge(options)
  end

  protected
  def create_class1_nanopub(annotation)
    if annotation =~ /(\w+):(\d+)\.\.(\d+),([#{@@AnnotationSignChars}])/
      chromosome, start_pos, end_pos, sign = $1, $2, $3, $4

      # setup nanopub
      nanopub = $base['cage_clusters/' + @row_index.to_s]
      assertion = nanopub['#assertion']
      provenance = nanopub['#provenance']
      publicationInfo = nanopub['#publicationInfo']

      # main graph
      create_main_graph(nanopub, assertion, provenance, publicationInfo)

      # assertion graph
      location = FANTOM5["loc_#{annotation}"]
      orientation = sign == '+' ? RSO.forward : RSO.reverse
      save(assertion, [
          [FANTOM5[annotation], RDF.type, SO.SO_0001917],
          [FANTOM5[annotation], RSO.mapsTo, location],
          [location, RDF.type, RSO.AnnotationLocation],
          [location, RSO.regionOf, HG19[chromosome]],
          [location, RSO.start, RDF::Literal.new(start_pos.to_i, :datatype => XSD.int)],
          [location, RSO.end, RDF::Literal.new(end_pos.to_i, :datatype => XSD.int)],
          [location, RSO.hasOrientation, orientation]
      ])

      # provenance graph
      create_provenance_graph(provenance, assertion)

      # publication info graph
      create_publication_info_graph(publicationInfo, nanopub)

      #puts "inserted nanopub <#{nanopub}>"
    else
      puts "Unknown annotation format: #{annotation}"
    end
  end

  protected
  def create_class2_nanopub(annotation, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot)
    if transcriptAssociation =~ /(\d+)bp_to_(.*)_5end/
      base_offset, transcripts = $1, $2
      transcripts = transcripts.split(',')

      # setup nanopub
      nanopub = RDF::Vocabulary.new($base['gene_associations/' + @row_index.to_s])
      assertion = nanopub['#assertion']
      provenance = nanopub['#provenance']
      publicationInfo = nanopub['#publicationInfo']

      transcriptForTss = transcripts[0]

      for transcript in transcripts
        if transcript =~ /^NM_/  #Note: NM transcript is preferred for tss_region url.
          transcriptForTss = transcript
        end
      end

      tss = FANTOM5["tss_#{transcriptForTss}"]
      entrez_id = geneEntrez.split(':')[1]

      # main graph
      create_main_graph(nanopub, assertion, provenance, publicationInfo)

      # assertion graph
      save(assertion, [
          [FANTOM5[annotation], RSO.is_observation_of, tss],
          [tss, RDF.type, SO.TSS_region],
          [tss, SO.part_of, RDF::URI.new("http://bio2rdf.org/geneid:#{entrez_id}")]
      ])

      # provenance graph
      create_provenance_graph(provenance, assertion)

      # publication info graph
      create_publication_info_graph(publicationInfo, nanopub)

      #puts "inserted nanopub <#{nanopub}>"
    else
      if transcriptAssociation != 'NA'
        puts "Unknown transcript association format: #{transcriptAssociation}"
      else
        puts "no transcript association on line #{@line_number}"
      end
    end
  end

  protected
  def create_class3_nanopub(annotation, samples)
    if samples.is_a?(Array)

      samples.each_with_index { |tpm, sample_index|

        if tpm.to_f > 0 #$ffont[sample_index] == @options[:celltype]

          nanopub = RDF::URI.new("http://rdf.biosemantics.org/nanopubs/riken/fantom5/ff_expressions/#{@row_index.to_s}/#{sample_index.to_s}")
          assertion = RDF::URI.new("http://rdf.biosemantics.org/nanopubs/riken/fantom5/ff_expressions/#{@row_index.to_s}/#{sample_index.to_s}#assertion")
          provenance = RDF::URI.new("http://rdf.biosemantics.org/nanopubs/riken/fantom5/ff_expressions/#{@row_index.to_s}/#{sample_index.to_s}#provenance")
          publicationInfo = RDF::URI.new("http://rdf.biosemantics.org/nanopubs/riken/fantom5/ff_expressions/#{@row_index.to_s}/#{sample_index.to_s}#provenance")

          measurementValue = RDF::URI.new("http://rdf.biosemantics.org/data/riken/fantom5/data#measurementValue/#{@row_index.to_s}/#{sample_index.to_s}")
          annotationURI = RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/data#'+annotation)

          # main graph
          create_main_graph(nanopub, assertion, provenance, publicationInfo)

          # assertion graph
          save(assertion, [
              [annotationURI, SO['associated_with'], measurementValue],
              # IAO_0000032 = scalar measurement datum
              [measurementValue, RDF.type, IAO.IAO_0000032],
              # IAO_0000004 = has_measurement_value
              [measurementValue, IAO['IAO_0000004'], RDF::Literal.new(tpm.to_f, :datatype => RDF::XSD.double)],
              # IAO_0000039 = has_measurement_unit_label
              [measurementValue, IAO['IAO_0000039'], FFU.TPM],
              [annotationURI, RSO.observed_in, FF[$ffont[sample_index]]]
          ])

          # provenance graph
          create_provenance_graph(provenance, assertion)

          # publication info graph
          create_publication_info_graph(publicationInfo, nanopub)

        end
      }
    else
      puts "Not an array of TPM values: #{samples} on line number #{@line_number}"
    end

  end

  private
  def create_provenance_graph(provenance, assertion)
    save(provenance, [
        [assertion, OBO.RO_0003001, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/experiment')],
        [assertion, PROV.derivedFrom, RDF::URI.new("http://rdf.biosemantics.org/dataset/riken/fantom5/void/row_#{@row_index}")]
    ])
  end

  private
  def create_publication_info_graph(publicationInfo, nanopub)
    save(publicationInfo, [
        [nanopub, PAV.authoredBy, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/project')],
        [nanopub, PAV.createdBy, RDF::Literal.new('Andrew Gibson', :datatype => XSD.string)] ,
        [nanopub, PAV.createdBy, RDF::Literal.new('Mark Thompson', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Zuotian Tatum', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Rajaram Kaliyaperumal', :datatype => XSD.string)],
        [nanopub, DC.rights, RDF::URI.new('http://creativecommons.org/licenses/by/3.0/')],
        [nanopub, DC.rightsHolder, RDF::URI.new('http://www.riken.jp/')],
        [nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]
    ])
  end
end

# do the work
Fantom5_Nanopub_Converter.new.convert