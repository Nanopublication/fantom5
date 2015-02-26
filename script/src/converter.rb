require 'rdf'
require 'rdf/allegro_graph'
require 'slop'
require 'logger'
require 'zlib'
require 'rubygems'
require 'rest_client'
require 'rexml/document'
include REXML

class RDF_Converter

  HEADER_PREFIX = '#'

  def initialize (rdfNs, npNs, prefix)

    @options = get_options
    $base = RDF::Vocabulary.new(@options[:base_url])
    $save_files = true
    # tracking converter progress
    @line_number = 0 # incremented after a line is read from input
    @row_index = 0 # incremented before a line is converted.
    @genes_skipped = 0    
    @rdf_statements_limit = 1000000
    $logger = Logger.new(STDOUT)
    $logger.level = Logger::INFO
    $RDF = rdfNs
    $NP = npNs
    $prefixes = prefix
  end

  def convert
    File.open(@options[:input], 'r') do |f|

      time_start = Time.now.utc

      while line = f.gets
        @line_number += 1
        if line =~ /^#{HEADER_PREFIX}/
          convert_header_row(line.strip)
        else
          convert_row(line.strip)
        end

        if @line_number % 10 == 0
          #$logger.info("============ running time: #{(Time.now.utc - time_start).to_s} ============")
        end

      end
      $logger.info("============ running time total: #{(Time.now.utc - time_start).to_s} ============")
    end

    if $save_files
      close_file()
    end

  end 
  

  protected
  def convert_header_row(row)
    # do something
    puts "header: #{row}"
  end

  protected
  def convert_row(row)
    # do something
    @row_index += 1
    puts "row #{@row_index.to_s}: #{row}"
  end

  protected
  def save(ctx, triples)
    throw NotImplementedError.new
  end

  protected
  def get_options
    options = Slop.parse(:help => true) do
      on :i, :input=, 'input filename', :required => true
      on :o, :output=, 'output filename'
    end
    options.to_hash
  end

  private
  def create_main_graph(nanopub, assertion, provenance, publication_info)
    save(nanopub, [
        [nanopub, $RDF.type, $NP.Nanopublication],
        [nanopub, $NP.hasAssertion, assertion],
        [nanopub, $NP.hasProvenance, provenance],
        [nanopub, $NP.hasPublicationInfo, publication_info]
    ])
  end

end

class RDF_File_Converter < RDF_Converter

  def initialize(rdf_ns, np_ns, prefix)
    super(rdf_ns, np_ns, prefix)
    $save_files = true
    $total_number_of_rdf_statements = 0
    $files_created = 0
    $number_of_rdf_statements = 0
    $file = nil
    $time_start = 0
  end

  def save(context, triples)
    triples.each do |subject, predicate, object|

      if $number_of_rdf_statements == 0
        $files_created += 1
        outputFile =  "#{@options[:output]}_#{$files_created}.nq.gz"
        $file = Zlib::GzipWriter.open(outputFile)
        $time_start = Time.now.utc
      end
      
      if object.literal?
        objectLiteral = ("\"#{object.to_s}\"^^<#{object.datatype}>")
        $file << ("<#{subject.to_uri}> <#{predicate.to_uri}> #{objectLiteral} <#{context.to_uri}> .")
      else
        $file << ("<#{subject.to_uri}> <#{predicate.to_uri}> <#{object.to_s}> <#{context.to_uri}> .")
      end

      $file << "\n"
      $number_of_rdf_statements += 1

      if $number_of_rdf_statements == @rdf_statements_limit
        close_file()
      end
    end

  end

  def close_file()

    $total_number_of_rdf_statements = $total_number_of_rdf_statements + $number_of_rdf_statements
    $number_of_rdf_statements = 0
    puts "No of statements in a file #{$total_number_of_rdf_statements}"
    
    if $file != nil
      $file.close
    end
    $logger.info((Time.now.utc - $time_start).to_s)
  end

end