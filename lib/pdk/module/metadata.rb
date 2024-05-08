require 'pdk'

module PDK
  module Module
    class Metadata
      attr_accessor :data

      OPERATING_SYSTEMS = {
        'RedHat based Linux' => [
          {
            'operatingsystem' => 'CentOS',
            'operatingsystemrelease' => ['7']
          },
          {
            'operatingsystem' => 'OracleLinux',
            'operatingsystemrelease' => ['7']
          },
          {
            'operatingsystem' => 'RedHat',
            'operatingsystemrelease' => ['8']
          },
          {
            'operatingsystem' => 'Scientific',
            'operatingsystemrelease' => ['7']
          }
        ],
        'Debian based Linux' => [
          {
            'operatingsystem' => 'Debian',
            'operatingsystemrelease' => ['10']
          },
          {
            'operatingsystem' => 'Ubuntu',
            'operatingsystemrelease' => ['18.04']
          }
        ],
        'Fedora' => {
          'operatingsystem' => 'Fedora',
          'operatingsystemrelease' => ['29']
        },
        'OSX' => {
          'operatingsystem' => 'Darwin',
          'operatingsystemrelease' => ['16']
        },
        'SLES' => {
          'operatingsystem' => 'SLES',
          'operatingsystemrelease' => ['15']
        },
        'Solaris' => {
          'operatingsystem' => 'Solaris',
          'operatingsystemrelease' => ['11']
        },
        'Windows' => {
          'operatingsystem' => 'windows',
          'operatingsystemrelease' => ['2019', '10']
        },
        'AIX' => {
          'operatingsystem' => 'AIX',
          'operatingsystemrelease' => ['6.1', '7.1', '7.2']
        }
      }.freeze

      DEFAULT_OPERATING_SYSTEMS = [
        'RedHat based Linux',
        'Debian based Linux',
        'Windows'
      ].freeze

      DEFAULTS = {
        'name' => nil,
        'version' => '0.1.0',
        'author' => nil,
        'summary' => '',
        'license' => 'Apache-2.0',
        'source' => '',
        'project_page' => nil,
        'issues_url' => nil,
        'dependencies' => [],
        'data_provider' => nil,
        'operatingsystem_support' => DEFAULT_OPERATING_SYSTEMS.dup,
        'requirements' => [
          { 'name' => 'puppet', 'version_requirement' => '>= 7.24 < 9.0.0' }
        ]
      }.freeze

      def initialize(params = {})
        @data = DEFAULTS.dup
        update!(params) if params
      end

      def self.from_file(metadata_json_path)
        raise ArgumentError, 'Cannot read metadata from file: no path to file was given.' if metadata_json_path.nil?

        raise ArgumentError, format("'%{file}' does not exist or is not a file.", file: metadata_json_path) unless PDK::Util::Filesystem.file?(metadata_json_path)

        raise ArgumentError, format("Unable to open '%{file}' for reading.", file: metadata_json_path) unless PDK::Util::Filesystem.readable?(metadata_json_path)

        require 'json'
        begin
          data = JSON.parse(PDK::Util::Filesystem.read_file(metadata_json_path))
        rescue JSON::JSONError => e
          raise ArgumentError, format('Invalid JSON in metadata.json: %{msg}', msg: e.message)
        end

        require 'pdk/util'
        data['template-url'] = PDK::Util::TemplateURI.default_template_uri.metadata_format if PDK::Util.package_install? && data['template-url'] == PDK::Util::TemplateURI::PACKAGED_TEMPLATE_KEYWORD
        new(data)
      end

      def update!(data)
        # TODO: validate all data
        process_name(data) if data['name']
        @data.merge!(data)
        self
      end

      def to_json(*_args)
        require 'json'

        JSON.pretty_generate(@data.dup.delete_if { |_key, value| value.nil? })
      end

      def write!(path)
        PDK::Util::Filesystem.write_file(path, to_json)
      end

      def forge_ready?
        missing_fields.empty?
      end

      def interview_for_forge!
        require 'pdk/generate/module'

        PDK::Generate::Module.module_interview(self, only_ask: missing_fields)
      end

      def validate_puppet_version_requirement!
        msgs = {
          no_reqs: 'Module metadata does not contain any requirements.',
          no_puppet_req: 'Module metadata does not contain a "puppet" requirement.',
          no_puppet_ver: 'The "puppet" requirement in module metadata does not specify a "version_requirement".'
        }

        raise ArgumentError, msgs[:no_reqs] unless @data.key?('requirements')
        raise ArgumentError, msgs[:no_puppet_req] if puppet_requirement.nil?
        raise ArgumentError, msgs[:no_puppet_ver] unless puppet_requirement.key?('version_requirement')
        raise ArgumentError, msgs[:no_puppet_ver] if puppet_requirement['version_requirement'].empty?
      end

      def puppet_requirement
        @data['requirements'].find do |r|
          r.key?('name') && r['name'] == 'puppet'
        end
      end

      def missing_fields
        fields = DEFAULTS.keys - ['data_provider', 'requirements', 'dependencies']
        fields.select { |key| @data[key].nil? || @data[key].empty? }
      end

      private

      # Do basic validation and parsing of the name parameter.
      def process_name(data)
        validate_name(data['name']) unless PDK.context.is_a?(PDK::Context::ControlRepo)
        author, modname = data['name'].split(%r{[-/]}, 2)
        data['name'] = [author, modname].join('-')

        data['author'] ||= author if @data['author'] == DEFAULTS['author']
      end

      # Validates that the given module name is both namespaced and well-formed.
      def validate_name(name)
        return if %r{\A[a-z0-9]+[-/][a-z][a-z0-9_]*\Z}i.match?(name)

        namespace, modname = name.split(%r{[-/]}, 2)
        modname = :namespace_missing if namespace == ''

        err = case modname
              when nil, '', :namespace_missing
                'Field must be a dash-separated user name and module name.'
              when /[^a-z0-9_]/i
                'Module name must contain only alphanumeric or underscore characters.'
              when /^[^a-z]/i
                'Module name must begin with a letter.'
              else
                'Namespace must contain only alphanumeric characters.'
              end

        raise ArgumentError, format("Invalid 'name' field in metadata.json: %{err}", err: err)
      end
    end
  end
end
