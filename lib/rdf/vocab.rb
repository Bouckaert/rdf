module RDF
  ##
  # A {Vocabulary} represents an RDFS or OWL vocabulary.
  #
  # ### Vocabularies:
  #
  # The following vocabularies are pre-defined for your convenience:
  #
  # * {RDF}         - Resource Description Framework (RDF)
  # * {RDF::CC}     - Creative Commons (CC)
  # * {RDF::CERT}   - W3 Authentication Certificate (CERT)
  # * {RDF::DC}     - Dublin Core (DC)
  # * {RDF::DC11}   - Dublin Core 1.1 (DC11) _deprecated_
  # * {RDF::DOAP}   - Description of a Project (DOAP)
  # * {RDF::EXIF}   - Exchangeable Image File Format (EXIF)
  # * {RDF::FOAF}   - Friend of a Friend (FOAF)
  # * {RDF::GEO}    - WGS84 Geo Positioning (GEO)
  # * {RDF::GR}     - Good Relations
  # * {RDF::HTTP}   - Hypertext Transfer Protocol (HTTP)
  # * {RDF::ICAL}   - iCal
  # * {RDF::MA}     - W3C Meda Annotations
  # * {RDF::OG}     - FaceBook OpenGraph
  # * {RDF::OWL}    - Web Ontology Language (OWL)
  # * {RDF::PROV}   - W3C Provenance Ontology
  # * {RDF::RDFS}   - RDF Schema (RDFS)
  # * {RDF::RSA}    - W3 RSA Keys (RSA)
  # * {RDF::RSS}    - RDF Site Summary (RSS)
  # * {RDF::SCHEMA} - Schema.org
  # * {RDF::SIOC}   - Semantically-Interlinked Online Communities (SIOC)
  # * {RDF::SKOS}   - Simple Knowledge Organization System (SKOS)
  # * {RDF::SKOSXL} - SKOS Simple Knowledge Organization System eXtension for Labels (SKOS-XL)
  # * {RDF::V}      - Data Vocabulary
  # * {RDF::VCARD}  - vCard vocabulary
  # * {RDF::VOID}   - Vocabulary of Interlinked Datasets (VoID)
  # * {RDF::WDRS}   - Protocol for Web Description Resources (POWDER)
  # * {RDF::WOT}    - Web of Trust (WOT)
  # * {RDF::XHTML}  - Extensible HyperText Markup Language (XHTML)
  # * {RDF::XHV}    - W3C XHTML Vocabulary
  # * {RDF::XSD}    - XML Schema (XSD)
  #
  # @example Using pre-defined RDF vocabularies
  #   include RDF
  #
  #   DC.title      #=> RDF::URI("http://purl.org/dc/terms/title")
  #   FOAF.knows    #=> RDF::URI("http://xmlns.com/foaf/0.1/knows")
  #   RDF.type      #=> RDF::URI("http://www.w3.org/1999/02/22-rdf-syntax-ns#type")
  #   RDFS.seeAlso  #=> RDF::URI("http://www.w3.org/2000/01/rdf-schema#seeAlso")
  #   RSS.title     #=> RDF::URI("http://purl.org/rss/1.0/title")
  #   OWL.sameAs    #=> RDF::URI("http://www.w3.org/2002/07/owl#sameAs")
  #   XSD.dateTime  #=> RDF::URI("http://www.w3.org/2001/XMLSchema#dateTime")
  #
  # @example Using ad-hoc RDF vocabularies
  #   foaf = RDF::Vocabulary.new("http://xmlns.com/foaf/0.1/")
  #   foaf.knows    #=> RDF::URI("http://xmlns.com/foaf/0.1/knows")
  #   foaf[:name]   #=> RDF::URI("http://xmlns.com/foaf/0.1/name")
  #   foaf['mbox']  #=> RDF::URI("http://xmlns.com/foaf/0.1/mbox")
  #
  # @see http://www.w3.org/TR/curie/
  # @see http://en.wikipedia.org/wiki/QName
  class Vocabulary
    extend ::Enumerable

    class << self
      ##
      # Enumerates known RDF vocabulary classes.
      #
      # @yield  [klass]
      # @yieldparam [Class] klass
      # @return [Enumerator]
      def each(&block)
        if self.equal?(Vocabulary)
          # This is needed since all vocabulary classes are defined using
          # Ruby's autoloading facility, meaning that `@@subclasses` will be
          # empty until each subclass has been touched or require'd.
          RDF::VOCABS.each { |v| require "rdf/vocab/#{v}" unless v == :rdf }
          @@subclasses.each(&block)
        else
          properties.each(&block)
        end
      end

      ##
      # Is this a strict vocabulary, or a liberal vocabulary allowing arbitrary properties?
      def strict?; false; end

      ##
      # @overload property
      #   Returns `property` in the current vocabulary
      #   @return [RDF::URI]
      #
      # @overload property(name, options)
      #   Defines a new property or class in the vocabulary.
      #
      #   @param [String, #to_s] name
      #   @param [Hash{Symbol => Object}] options
      #     Symbol forms are supported for `:label` and `:comment`. Any other values are expected to be {Term} with a {Term} or {Array<Term>} value. These can be used to regenerate the RDF definition of the vocabulary property/term
      #   @option options [Literal, #to_s] :label
      #   @option options [Literal, #to_s] :comment
      def property(*args)
        case args.length
        when 0
          Term.intern("#{self}property", attributes: {:label => "property"})
        else
          name, options = args
          options = {:label => name.to_s}.merge(options || {})
          prop = Term.intern([to_s, name.to_s].join(''), attributes: options)
          props[prop] = options
          (class << self; self; end).send(:define_method, name) { prop } unless name.to_s == "property"
        end
      end

      # Alternate use for vocabulary terms, functionally equivalent to {#property}.
      alias_method :term, :property

      ##
      #  @return [Array<RDF::URI>] a list of properties in the current vocabulary
      def properties
        props.keys
      end

      ##
      # Returns the URI for the term `property` in this vocabulary.
      #
      # @param  [#to_s] property
      # @return [RDF::URI]
      def [](property)
        if self.respond_to?(property.to_sym)
          self.send(property.to_sym)
        else
          Term.intern([to_s, property.to_s].join(''), attributes: {:label => property.to_s})
        end
      end

      # @return [String] The label for the named property
      def label_for(name)
        props.fetch(self[name], {}).fetch(:label, "")
      end

      # @return [String] The comment for the named property
      def comment_for(name)
        props.fetch(self[name], {}).fetch(:comment, "")
      end

      ##
      # Returns the base URI for this vocabulary class.
      #
      # @return [RDF::URI]
      def to_uri
        RDF::URI.intern(to_s)
      end

      # For IRI compatibility
      alias_method :to_iri, :to_uri

      ##
      # Returns a string representation of this vocabulary class.
      #
      # @return [String]
      def to_s
        @@uris.has_key?(self) ? @@uris[self].to_s : super
      end

      ##
      # Returns a developer-friendly representation of this vocabulary class.
      #
      # @return [String]
      def inspect
        if self == Vocabulary
          self.to_s
        else
          sprintf("%s(%s)", superclass.to_s, to_s)
        end
      end

      # Preserve the class name so that it can be obtained even for
      # vocabularies that define a `name` property:
      alias_method :__name__, :name

      ##
      # Returns a suggested CURIE/QName prefix for this vocabulary class.
      #
      # @return [Symbol]
      # @since  0.3.0
      def __prefix__
        __name__.split('::').last.downcase.to_sym
      end

    protected
      def inherited(subclass) # @private
        unless @@uri.nil?
          @@subclasses << subclass #unless subclass == ::RDF::RDF
          subclass.send(:private_class_method, :new)
          @@uris[subclass] = @@uri
          @@uri = nil
        end
        super
      end

      def method_missing(property, *args, &block)
        if args.empty? && !to_s.empty?
          Term.intern([to_s, property.to_s].join(''), attributes: {:label => property.to_s})
        else
          super
        end
      end

    private
      def props; @properties ||= {}; end
    end

    # Undefine all superfluous instance methods:
    undef_method(*instance_methods.
                  map(&:to_s).
                  select {|m| m =~ /^\w+$/}.
                  reject {|m| %w(object_id dup instance_eval inspect to_s class).include?(m) || m[0,2] == '__'}.
                  map(&:to_sym))

    ##
    # @param  [RDF::URI, String, #to_s] uri
    def initialize(uri)
      @uri = case uri
        when RDF::URI then uri.to_s
        else RDF::URI.parse(uri.to_s) ? uri.to_s : nil
      end
    end

    ##
    # Returns the URI for the term `property` in this vocabulary.
    #
    # @param  [#to_s] property
    # @return [URI]
    def [](property)
      Term.intern([to_s, property.to_s].join(''), attributes: {:label => property.to_s})
    end

    ##
    # Returns the base URI for this vocabulary.
    #
    # @return [URI]
    def to_uri
      RDF::URI.intern(to_s)
    end

    # For IRI compatibility
    alias_method :to_iri, :to_uri

    ##
    # Returns a string representation of this vocabulary.
    #
    # @return [String]
    def to_s
      @uri.to_s
    end

    ##
    # Returns a developer-friendly representation of this vocabulary.
    #
    # @return [String]
    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, to_s)
    end

  protected

    def self.create(uri) # @private
      @@uri = uri
      self
    end

    def method_missing(property, *args, &block)
      if args.empty?
        self[property]
      else
        raise ArgumentError.new("wrong number of arguments (#{args.size} for 0)")
      end
    end

  private

    @@subclasses = [::RDF] # @private
    @@uris       = {}      # @private
    @@uri        = nil     # @private

    # A Vocabulary Term is a URI that can also act as an {Enumerable} to generate the RDF definition of vocabulary terms as defined within the vocabulary definition.
    class Term < RDF::URI
      # Attributes of this vocabulary term, used for finding `label` and `comment` and to serialize the term back to RDF.
      # @return [Hash{Symbol,Resource => Term, #to_s}]
      attr_accessor :attributes
      include RDF::Enumerable

      ##
      # @overload URI(uri, options = {})
      #   @param  [URI, String, #to_s]    uri
      #   @param  [Hash{Symbol => Object}] options
      #   @option options [Boolean] :validate (false)
      #   @option options [Boolean] :canonicalize (false)
      #   @option options [Hash{Symbol,Resource => Term, #to_s}] :attributes
      #     Attributes of this vocabulary term, used for finding `label` and `comment` and to serialize the term back to RDF
      #
      # @overload URI(options = {})
      #   @param  [Hash{Symbol => Object}] options
      #   @option options [Boolean] :validate (false)
      #   @option options [Boolean] :canonicalize (false)
      #   @option [String, #to_s] :scheme The scheme component.
      #   @option [String, #to_s] :user The user component.
      #   @option [String, #to_s] :password The password component.
      #   @option [String, #to_s] :userinfo
      #     The userinfo component. If this is supplied, the user and password
      #     components must be omitted.
      #   @option [String, #to_s] :host The host component.
      #   @option [String, #to_s] :port The port component.
      #   @option [String, #to_s] :authority
      #     The authority component. If this is supplied, the user, password,
      #     userinfo, host, and port components must be omitted.
      #   @option [String, #to_s] :path The path component.
      #   @option [String, #to_s] :query The query component.
      #   @option [String, #to_s] :fragment The fragment component.
      #   @option options [Hash{Symbol,Resource => Term, #to_s}] :attributes
      #     Attributes of this vocabulary term, used for finding `label` and `comment` and to serialize the term back to RDF
      def initialize(*args)
        options = args.last.is_a?(Hash) ? args.last : {}
        @attributes = options.fetch(:attributes)
        super
      end

      ##
      # Returns a duplicate copy of `self`.
      #
      # @return [RDF::URI]
      def dup
        self.class.new((@value || @object).dup, attributes: @attributes)
      end

      ##
      # Label for this vocabulary term
      # @return [String]
      def label
        @attributes.fetch(:label, "")
      end

      ##
      # Comment for this vocabulary term
      # @return [String]
      def comment
        @attributes.fetch(:comment, "")
      end

      ##
      # Enumerate {RDF::Statement} defined for this term
      #
      # @yield statement
      # @yieldparam [RDF::Statement] statement
      # @return [Enumerator]
      def each(&block)
        @attributes.each do |prop, values|
          Array(values).each do |value|
            case prop
            when :label
              yield RDF::Statement(self, RDFS.label, value)
            when :comment
              yield RDF::Statement(self, RDFS.comment, value)
            when RDF::Resource
              yield RDF::Statement(self, prop, value)
            end
          end
        end
      end

      ##
      # Determine if the URI is a valid according to RFC3987
      #
      # @return [Boolean] `true` or `false`
      # @since 0.3.9
      def valid?
        # Validate relative to RFC3987
        to_s.match(RDF::URI::IRI) || false
      end

      ##
      # Returns a <code>String</code> representation of the URI object's state.
      #
      # @return [String] The URI object's state, as a <code>String</code>.
      def inspect
        sprintf("#<%s:%#0x URI:%s>", Term.to_s, self.object_id, self.to_s)
      end
    end
  end # Vocabulary

  # Represents an RDF Vocabulary. The difference from {RDF::Vocabulary} is that
  # that every concept in the vocabulary is required to be declared. To assist
  # in this, an existing RDF representation of the vocabulary can be loaded as
  # the basis for concepts being available
  class StrictVocabulary < Vocabulary
    class << self
      # Redefines method_missing to the original definition
      # By remaining a subclass of Vocabulary, we remain available to
      # Vocabulary::each etc.
      define_method(:method_missing, BasicObject.instance_method(:method_missing))

      ##
      # Is this a strict vocabulary, or a liberal vocabulary allowing arbitrary properties?
      def strict?; true; end

      def [](name)
        prop = super
        props.fetch(prop) #raises KeyError on missing value
        return prop
      end
    end
  end # StrictVocabulary
end # RDF
