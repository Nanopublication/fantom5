# Example arguments (Shell script):
# ruby fantom5.rb --input /home/raja/fantom5/fantom5DS.txt --output /home/raja/fantom5/fantom5-np/fantom5 --subtype ff_expressions --username raja --password raja --catalog system --repository test --host localhost --port 10035
#
# Example arguments (Rubymine):
# '-help --input /home/raja/fantom5/fantom5DS.txt --output /home/raja/fantom5/fantom5-np/fantom5 --subtype ff_expressions --username raja --password raja --catalog system --repository test --host localhost --port 10035'

require 'rdf'
require 'slop'
require_relative 'converter'

class Fantom5_Nanopub_Converter < RDF_File_Converter

  # URIs string
  $base_url = 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/'
  $resource_url = 'http://rdf.biosemantics.org/resource/riken/fantom5/'

  # Define some useful RDF vocabularies.(Note: Define subclass RDF vocabularies here)
  FOAF = RDF::FOAF
  DC = RDF::DC
  RDFS = RDF::RDFS
  XSD = RDF::XSD
  RSO = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/rsa#')
  HG19 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/hg19#')
  SO = RDF::Vocabulary.new('http://purl.obolibrary.org/obo/')
  PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
  OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
  PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
  NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')
  SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')
  FF = RDF::Vocabulary.new('http://purl.obolibrary.org/obo/FF_')
  IAO = RDF::Vocabulary.new('http://purl.obolibrary.org/obo/')
  FFU = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/fantom5Units#')
  FANTOM5 = RDF::Vocabulary.new($resource_url)
  $base = RDF::Vocabulary.new($base_url)


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

    @NANOPUB_VERSION = 1.0

    super(RDF, NP, prefixes)

  end

  @@AnnotationSignChars = '+-'

  def convert_header_row(row)
    # do nothing
    # ignore summary rows
  end

  def convert_row(row)

    @row_index += 1
    annotation, shortDesc, description, transcript_association, gene_entrez, gene_hgnc, gene_uniprot, *samples = row.split("\t")  

    case @options[:subtype]
      when 'cage_clusters'
        create_class1_nanopub(annotation)
      when 'gene_associations'
        create_class2_nanopub(annotation, transcript_association, gene_entrez, gene_hgnc, gene_uniprot)
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
      nanopub = RDF::URI.new("#{$base_url}cage_clusters/#{@row_index.to_s}")
      assertion = RDF::URI.new("#{$base_url}cage_clusters/#{@row_index.to_s}#assertion")
      provenance = RDF::URI.new("#{$base_url}cage_clusters/#{@row_index.to_s}#provenance")
      publication_info = RDF::URI.new("#{$base_url}cage_clusters/#{@row_index.to_s}#publicationInfo")

      # main graph
      create_main_graph(nanopub, assertion, provenance, publication_info)

      # assertion graph
      cage_cluster = RDF::URI.new("#{$resource_url}cage_cluster_#{@row_index.to_s}")
      location = RDF::URI.new("#{$resource_url}annotation_location_#{@row_index.to_s}")

      orientation = sign == '+' ? RSO.forward : RSO.reverse
      save(assertion, [
          # SO_0001917 = cage cluster
          [cage_cluster, RDF.type, SO['SO_0001917']],
          [cage_cluster, RSO['mapsTo'], location],
          [cage_cluster, RDFS.label, RDF::Literal.new(annotation, :datatype => XSD.string)],
          [location, RDF.type, RSO['AnnotationLocation']],
          [location, RSO['regionOf'], HG19[chromosome]],
          [location, RSO['start'], RDF::Literal.new(start_pos.to_i, :datatype => XSD.int)],
          [location, RSO['end'], RDF::Literal.new(end_pos.to_i, :datatype => XSD.int)],
          [location, RSO['hasOrientation'], orientation]
      ])

      # provenance graph
      create_provenance_graph(provenance, assertion)

      # publication info graph
      create_publication_info_graph(publication_info, nanopub)

      #puts "inserted nanopub <#{nanopub}>"
    else
      puts "Unknown annotation format: #{annotation}"
    end
  end

  protected
  def create_class2_nanopub(annotation, transcript_association, gene_entrez, gene_hgnc, gene_uniprot)
    
    if transcript_association =~ /(\d+)bp_to_(.*)_5end/
      entrez_genes = gene_entrez.split(',')
      entrez_ids = Array.new
      
      for entrezGene in entrez_genes
        entrez_id = entrezGene.split('entrezgene:')[1]

        if entrez_id != '' && entrez_id !=nil
          entrez_ids << entrez_id
        end
      end
      
     if  entrez_ids.size > 0
       # setup nanopub
       nanopub = RDF::URI.new("#{$base_url}gene_associations/#{@row_index.to_s}")
       assertion = RDF::URI.new("#{$base_url}gene_associations/#{@row_index.to_s}#assertion")
       provenance = RDF::URI.new("#{$base_url}gene_associations/#{@row_index.to_s}#provenance")
       publication_info = RDF::URI.new("#{$base_url}gene_associations/#{@row_index.to_s}#publicationInfo")

       # main graph
       create_main_graph(nanopub, assertion, provenance, publication_info)

      # assertion graph
       cage_cluster = RDF::URI.new("#{$resource_url}cage_cluster_#{@row_index.to_s}")
       tss_region = RDF::URI.new("#{$resource_url}tss_region_#{@row_index.to_s}")
       #tss_region = RDF::URI.new("#{$resource_url}tss_region_#{transcriptForTss}")

       save(assertion, [
           [cage_cluster, RSO['is_observation_of'], tss_region],
           # SO_0001240 = TSS_region
           [tss_region, RDF.type, SO['SO_0001240']]
       ])
       
       number_of_genes = 0

       for gene_id in entrez_ids

         number_of_genes +=1

         gene = RDF::URI.new("#{$resource_url}gene_#{@row_index.to_s}_#{number_of_genes}")
         
         save(assertion, [
             [tss_region, SO['so_associated_with'], gene],
             # SO_0000704 = gene
             [gene, RDF.type, SO['SO_0000704']],
             [gene, DC.identifier, RDF::Literal.new(gene_id, :datatype => XSD.int)],
             [gene, RDF.seeAlso, RDF::URI.new("http://linkedlifedata.com/resource/entrezgene/id/#{gene_id}")]
         ])

       end

      # provenance graph
       create_provenance_graph(provenance, assertion)
       
      # publication info graph
       create_publication_info_graph(publication_info, nanopub)

     end


    else
      if transcript_association != 'NA'
        puts "Unknown transcript association format: #{transcript_association}"
      else
        #puts "no transcript association on line #{@line_number}"
      end
    end
  end
  
  protected
  def create_class3_nanopub(annotation, samples)
    if samples.is_a?(Array)

      samples.each_with_index { |tpm, sample_index|

        if tpm.to_f > 0
          
          # setup nanopub
          nanopub = RDF::URI.new("#{$base_url}ff_expressions/#{@row_index.to_s}_#{sample_index.to_s}")
          assertion = RDF::URI.new("#{$base_url}ff_expressions/#{@row_index.to_s}_#{sample_index.to_s}#assertion")
          provenance = RDF::URI.new("#{$base_url}ff_expressions/#{@row_index.to_s}_#{sample_index.to_s}#provenance")
          publication_info = RDF::URI.new("#{$base_url}ff_expressions/#{@row_index.to_s}_#{sample_index.to_s}#publicationInfo")

          # main graph
          create_main_graph(nanopub, assertion, provenance, publication_info)

          # assertion graph
          cage_cluster = RDF::URI.new("#{$resource_url}cage_cluster_#{@row_index.to_s}")
          measurement_value = RDF::URI.new("#{$resource_url}measurement_value_#{@row_index.to_s}_#{sample_index.to_s}")

          save(assertion, [
              [cage_cluster, SO['so_associated_with'], measurement_value],
              # IAO_0000032 = scalar measurement datum
              [measurement_value, RDF.type, IAO.IAO_0000032],
              # IAO_0000004 = has_measurement_value
              [measurement_value, IAO['IAO_0000004'], RDF::Literal.new(tpm.to_f, :datatype => RDF::XSD.double)],
              # IAO_0000039 = has_measurement_unit_label
              [measurement_value, IAO['IAO_0000039'], FFU.TPM],
              [cage_cluster, RSO['observed_in'], FF[$ffont[sample_index]]]
          ])
          
          # provenance graph
          create_provenance_graph(provenance, assertion)

          # publication info graph
          create_publication_info_graph(publication_info, nanopub)

        else
          #puts "Sample #{$ffont[sample_index]} has tpm value ZERO"          
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
  def create_publication_info_graph(publication_info, nanopub)
    save(publication_info, [
        [nanopub, PAV.authoredBy, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/project')],
        [nanopub, PAV.createdBy, RDF::Literal.new('Andrew Gibson', :datatype => XSD.string)] ,
        [nanopub, PAV.createdBy, RDF::Literal.new('Mark Thompson', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Zuotian Tatum', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Rajaram Kaliyaperumal', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Eelke van der Horst', :datatype => XSD.string)],
        [nanopub, PAV.createdBy, RDF::Literal.new('Kees Burger', :datatype => XSD.string)],
        [nanopub, DC.rights, RDF::URI.new('http://creativecommons.org/licenses/by/3.0/')],
        [nanopub, DC.rightsHolder, RDF::URI.new('http://www.riken.jp/')],
        [nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]
    ])


  end
end

# do the work
Fantom5_Nanopub_Converter.new.convert