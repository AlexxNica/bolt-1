require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "when runnning over the ssh transport", ssh: true do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration

  let(:whoami) { "whoami" }
  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:stdin_task) { "sample::stdin" }
  let(:uri) { conn_uri('ssh') }
  let(:user) { conn_info('ssh')[:user] }
  let(:password) { conn_info('ssh')[:password] }

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  context 'when using CLI options' do
    let(:config_flags) { %W[--nodes #{uri} --insecure --format json --modulepath #{modulepath} --password #{password}] }

    it 'runs a command' do
      result = run_one_node(%W[command run #{whoami}] + config_flags)
      expect(result['stdout'].strip).to eq(
        conn_info('ssh')[:user]
      )
    end

    it 'runs a task', reset_puppet_settings: true do
      result = run_one_node(%W[task run #{stdin_task} message=somemessage] + config_flags)
      expect(result['message'].strip).to eq("somemessage")
    end

    it 'passes noop to a task that supports noop', reset_puppet_settings: true do
      result = run_one_node(%w[task run sample::noop message=somemessage --noop] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop true")
    end

    it 'does not pass noop to a task by default', reset_puppet_settings: true do
      result = run_one_node(%w[task run sample::noop message=somemessage] + config_flags)
      expect(result['_output'].strip).to eq("somemessage with noop")
    end

    it 'escalates privileges when passed --run-as' do
      result = run_one_node(%W[command run #{whoami} --run-as root --sudo-password #{password}] + config_flags)
      expect(result['stdout'].strip).to eq("root")
      result = run_one_node(%W[command run #{whoami} --run-as #{user} --sudo-password #{password}] + config_flags)
      expect(result['stdout'].strip).to eq(user)
    end
  end

  context 'when using a configfile' do
    let(:config) do
      { 'format' => 'json',
        'modulepath' => modulepath,
        'ssh' => {
          'insecure' => true
        } }
    end

    let(:config_flags) { %W[--nodes #{uri} --password #{password}] }

    it 'runs a command' do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[command run #{whoami} --configfile #{conf.path}] + config_flags)
        expect(result['stdout'].strip).to eq(conn_info('ssh')[:user])
      end
    end

    it 'runs a task', reset_puppet_settings: true do
      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[task run #{stdin_task} message=somemessage --configfile #{conf.path}] + config_flags)
        expect(result['message'].strip).to eq("somemessage")
      end
    end

    it 'runs a task as a specified user', reset_puppet_settings: true do
      config['ssh']['run-as'] = user

      with_tempfile_containing('conf', YAML.dump(config)) do |conf|
        result = run_one_node(%W[command run #{whoami} --configfile #{conf.path}
                                 --sudo-password #{password}] + config_flags)
        expect(result['stdout'].strip).to eq(user)
      end
    end
  end
end
