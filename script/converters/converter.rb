require 'rdf'
require 'rdf/turtle'
require 'rdf/allegro_graph'
require 'slop'
require 'logger'
require 'rdf/trig'
require 'linkeddata'
require 'rdf/nquads'

class RDF_Converter

  HEADER_PREFIX = '#'

  def initialize (rdfNs, npNs, prefix)

    @options = get_options
    #@base = RDF::Vocabulary.new("#{@options[:base_url]}/HD_associations/")
    @base = RDF::Vocabulary.new(@options[:base_url])
    @graphHashKey = 0
    @graphHash = Hash.new
    @saveFiles = false

    # tracking converter progress
    @line_number = 0 # incremented after a line is read from input
    @row_index = 0 # incremented before a line is converted.


    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    @RDF = rdfNs
    @NP = npNs
    @prefixes = prefix
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
          #@logger.info("============ running time: #{(Time.now.utc - time_start).to_s} ============")
          #puts ("#{(Time.now.utc - time_start).to_s}")
        end

      end

      @logger.info("============ running time total: #{(Time.now.utc - time_start).to_s} ============")
    end

    if @saveFiles
      writeFile()
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
    # old code replace @base with nanopub
    save(nanopub, [
        [nanopub, @RDF.type, @NP.Nanopublication],
        [nanopub, @NP.hasAssertion, assertion],
        [nanopub, @NP.hasProvenance, provenance],
        [nanopub, @NP.hasPublicationInfo, publication_info]
    ])
  end

end

class RDF_File_Converter < RDF_Converter

  def initialize(rdfNs, npNs, prefix)
    super(rdfNs, npNs, prefix)
    @saveFiles = true
    @repo = RDF::Repository.new
    @totalStatements = 0
    @fileCreated = 0
    @NoOfStatements = 0
    @file = nil
  end



  def save(ctx, triples)
    triples.each do |s, p, o|
      #@repo  << RDF::Statement.new(s.to_uri, p, o, :context => ctx.to_uri)

      if @NoOfStatements == 0

        @fileCreated += 1
        outputFile =  "#{@options[:output]}_#{@fileCreated}.nq.gz"
        @file = Zlib::GzipWriter.open(outputFile);

      end

      #line = "<#{s.to_uri}><#{p.to_uri}><#{o.to_uri}><#{ctx.to_uri}>"

      @file << RDF::Statement.new(s.to_uri, p, o, :context => ctx.to_uri)
      #puts "This is object ==   #{o.}"
      #@file << ("<#{s.to_uri}> <#{p}> #{o} <#{ctx.to_uri}> .")
      @file << "\n"

      @NoOfStatements += 1

      if @NoOfStatements > 1000000
        writeFile()

      end


      #if @repo.size > 1000000
        #writeFile();
      #end
    end

  end

  def writeFile()

    @totalStatements = @totalStatements + @NoOfStatements
    @NoOfStatements = 0

    puts "Total no of statements in a file #{@totalStatements}"
    if @file != nil
      @file.close
    end


    #@fileCreated += 1

    #if @repo.size > 0

     # @totalStatements = @totalStatements + @repo.size

      #outputFile =  "#{@options[:output]}_#{@fileCreated}.nq.gz"
      #file = Zlib::GzipWriter.open(outputFile); # File.open(@options[:output], "w")
      #file << @repo.dump(:nquads)
      #file.close
      #File.open(outputFile, "w") {|f| f << @repo.dump(:nquads)}
      #@repo.clear
      #puts "No 0f Statements = #{@totalStatements}"
    #end
  end

  def writeSingleFile()
    @fileCreated +=1

    outputFile =  "#{@options[:output]}.nq"
    File.open(outputFile, "w") {|f| f << @repo.dump(:nquads)}

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
  def save(ctx, triples)
    ctx_uri = ctx.to_uri
    triples.each do |s, p, o|
      @repository.insert([s.to_uri, p, o, ctx_uri])
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