require 'spec_helper'
require 'pdk/cli'

describe 'PDK::CLI new defined_type' do
  let(:help_text) { a_string_matching(/^USAGE\s+pdk new defined_type/m) }

  before do
    allow(PDK::Util).to receive(:module_root).and_return(module_root)

    # Stop printing out the result
    allow(PDK::CLI::Util::UpdateManagerPrinter).to receive(:print_summary)
  end

  shared_examples 'it exits non-zero and prints the help text' do
    it 'exits non-zero and prints the `pdk new defined_type` help' do
      expect { PDK::CLI.run(args) }.to exit_nonzero.and output(help_text).to_stdout
    end
  end

  shared_examples 'it exits with an error' do |expected_error|
    it 'exits with an error' do
      expect(logger).to receive(:error).with(a_string_matching(expected_error))

      expect { PDK::CLI.run(args) }.to exit_nonzero
    end
  end

  context 'when not run from inside a module' do
    include_context 'run outside module'
    let(:module_root) { nil }
    let(:args) { ['new', 'defined_type', 'test_define'] }

    it_behaves_like 'it exits with an error', /must be run from inside a valid module/
  end

  context 'when run from inside a module' do
    let(:module_root) { '/path/to/test/module' }

    context 'and not provided with a name for the new defined type' do
      let(:args) { ['new', 'defined_type'] }

      it_behaves_like 'it exits non-zero and prints the help text'
    end

    context 'and provided an empty string as the defined type name' do
      let(:args) { ['new', 'defined_type', ''] }

      it_behaves_like 'it exits non-zero and prints the help text'
    end

    context 'and provided an invalid defined type name' do
      let(:args) { ['new', 'defined_type', 'test-define'] }

      it_behaves_like 'it exits with an error', /'test-define' is not a valid defined type name/
    end

    context 'and provided a valid defined type name' do
      let(:generator) { PDK::Generate::DefinedType }
      let(:generator_double) { instance_double(generator, run: true) }
      let(:generator_opts) { instance_of(Hash) }

      before do
        allow(generator).to receive(:new).with(anything, 'test_define', generator_opts).and_return(generator_double)
      end

      after do
        PDK::CLI.run(['new', 'defined_type', 'test_define'])
      end

      it 'generates the defined type' do
        expect(generator_double).to receive(:run)
      end
    end
  end
end
