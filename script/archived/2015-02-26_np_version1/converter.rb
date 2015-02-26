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

    $saveFiles = false

    # tracking converter progress
    @line_number = 0 # incremented after a line is read from input
    @row_index = 0 # incremented before a line is converted.
    @genesSkipped = 0


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

    if $saveFiles
      closeFile()
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

  def initialize(rdfNs, npNs, prefix)
    super(rdfNs, npNs, prefix)
    $saveFiles = true
    $totalStatements = 0
    $filesCreated = 0
    $NoOfStatements = 0
    $file = nil
    $time_start = 0

  end



  def save(context, triples)
    triples.each do |subject, predicate, object|

      if $NoOfStatements == 0

        $filesCreated += 1
        outputFile =  "#{@options[:output]}_#{$filesCreated}.nq.gz"
        $file = Zlib::GzipWriter.open(outputFile)
        $time_start = Time.now.utc
      end

      #@file << RDF::Statement(subject.to_uri, predicate, object, :context => context.to_uri)
      if object.literal?
        objectLiteral = ("\"#{object.to_s}\"^^<#{object.datatype}>")
        $file << ("<#{subject.to_uri}> <#{predicate.to_uri}> #{objectLiteral} <#{context.to_uri}> .")
      else
        $file << ("<#{subject.to_uri}> <#{predicate.to_uri}> <#{object.to_s}> <#{context.to_uri}> .")
      end

      $file << "\n"

      $NoOfStatements += 1

      if $NoOfStatements == 1000000
        closeFile()
      end
    end

  end

  def closeFile()

    $totalStatements = $totalStatements + $NoOfStatements
    $NoOfStatements = 0

    puts "No of statements in a file #{$totalStatements}"
    if $file != nil
      $file.close
    end
    $logger.info((Time.now.utc - $time_start).to_s)
  end

end

class RDF_Nanopub_Converter < RDF_Converter


  def initialize(rdfNs, npNs, prefix)

    super(rdfNs, npNs, prefix)

    @server = AllegroGraph::Server.new(:host => @options[:host], :port => @options[:port],
                                       :username => @options[:username], :password => @options[:password])

    @catalog = @options[:catalog] ? AllegroGraph::Catalog.new(@server, @options[:catalog]) : @server
    @repository = @RDF::AllegroGraph::Repository.new(:server => @catalog, :id => @options[:repository])

    if @options[:clean]
      @repository.clear
    elsif @repository.size > 0 && !@options[:append]
      puts "repository is not empty (size = #{@repository.size}). Use --clean to clear repository before import, or use --append to ignore this setting."
      exit 1
    end
  end

  protected
  def save(context, triples)
    triples.each do |subject, predicate, object|
      @repository.insert([subject.to_uri, predicate, object, context.to_uri])
    end
  end

  protected
  def get_options
    options = Slop.parse(:help => true) do
      on :host=, 'allegro graph host, default=localhost', :default => 'localhost'
      on :port=, 'default=10035', :as => :int, :default => 10035
      on :catalog=
      on :repository=, :required => true
      on :username=
      on :password=
      on :clean, 'clear the repository before import', :default => false
      on :append, 'allow adding new triples to a non-empty triple store.', :default => false
    end

    super.merge(options)
  end


end