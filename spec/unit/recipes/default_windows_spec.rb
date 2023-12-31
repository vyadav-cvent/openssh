require 'spec_helper'

describe 'openssh::default' do
  context 'Windows' do
    platform 'windows', '2016'

    let(:ssh_config_path) { join_path('C:\\ProgramData\\ssh', 'ssh_config') }
    let(:sshd_config_path) { join_path('C:\\ProgramData\\ssh', 'sshd_config') }
    let(:ca_keys_path) { join_path('C:\\ProgramData\\ssh', 'ca_userkeys.pub') }
    let(:revoked_keys_path) { join_path('C:\\ProgramData\\ssh', 'revoked_keys') }

    describe 'ssh_config' do
      it 'writes the ssh_config' do
        template = chef_run.template(ssh_config_path)
        expect(template).to be
      end
    end

    describe 'sshd_config' do
      it 'writes the sshd_config' do
        template = chef_run.template(sshd_config_path)
        expect(template).to be
      end

      it 'does not use PAM option on Windows' do
        expect(chef_run).to_not render_file(sshd_config_path).with_content(/UsePAM/)
      end

      it 'allow legacy default AuthorizedKeysFile behavior' do
        expect(chef_run).to_not render_file(sshd_config_path).with_content(/AuthorizedKeysFile.*/)
      end

      it 'writes a match group block' do
        chef_run.node.override['openssh']['server']['match'] = { 'Group admins' => { 'permit_tunnel' => 'yes' } }
        chef_run.converge('openssh::default')
        expect(chef_run).to render_file(sshd_config_path).with_content(/Match Group admins\n\s\sPermitTunnel yes/)
      end

      it 'skips match group block' do
        chef_run.node.override['openssh']['server']['match'] = {}
        chef_run.converge('openssh::default')
        expect(chef_run).to_not render_file(sshd_config_path).with_content(/Match Group admins\n\s\sPermitTunnel yes/)
      end

      it 'write multiple SSH subsystems from Hash' do
        chef_run.node.override['openssh']['server']['subsystem'] = {
          sftp: '/usr/lib/openssh/sftp-server',
          test: '/my/subsystem/bin',
        }
        chef_run.converge('openssh::default')
        expect(chef_run).to render_file(sshd_config_path).with_content(%r{Subsystem sftp \/usr\/lib\/openssh\/sftp-server\nSubsystem test.*})
      end

      it 'skips subsystems block' do
        chef_run.node.override['openssh']['server']['subsystem'] = {}
        chef_run.converge('openssh::default')
        expect(chef_run).to_not render_file(sshd_config_path).with_content(/^Subsystem?/)
      end

      it 'supports legacy subsystem format' do
        chef_run.node.override['openssh']['server']['subsystem'] = 'sftp /usr/lib/openssh/sftp-server'
        chef_run.converge('openssh::default')
        expect(chef_run).to render_file(sshd_config_path).with_content(%r{Subsystem sftp \/usr\/lib\/openssh\/sftp-server\n})
      end

      it 'allows subsystem from Array attribute' do
        chef_run.node.override['openssh']['server']['subsystem'] = [
          'sftp /usr/lib/openssh/sftp-server',
          'test /my/subsystem/bin',
        ]
        chef_run.converge('openssh::default')
        expect(chef_run).to render_file(sshd_config_path).with_content(%r{Subsystem sftp \/usr\/lib\/openssh\/sftp-server\nSubsystem test.*})
      end

      context 'port set without listen address set' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new(platform: 'windows', version: '2016') do |node|
            node.normal['openssh']['server']['port'] = 1234
          end.converge('openssh::default')
        end

        it 'writes out port at the top of the config' do
          expect(chef_run).to render_file(sshd_config_path)
            .with_content(/# Do NOT modify this file by hand!\n\nPort 1234/)
        end
      end

      context 'supports multiple ports' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new(platform: 'windows', version: '2016') do |node|
            node.normal['openssh']['server']['port'] = [1234, 1235]
          end.converge('openssh::default')
        end

        it 'writes both ports to sshd_config' do
          expect(chef_run).to render_file(sshd_config_path)
            .with_content(/Port 1234/)
            .with_content(/Port 1235/)
        end
      end

      context 'supports ca keys and revoked keys' do
        cached(:chef_run) do
          ChefSpec::SoloRunner.new(platform: 'windows', version: '2016') do |node|
            node.normal['openssh']['ca_keys'] = ['ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJt7VN0YkI2jVnWUod8I/Qy9Am4lq0VOmFUTbzrMVTM8iut8E7heWu8G5QsDFLi3BNcU5wnwWO8rTWZZh1CJq6+zVn010rUYZhDxjlvFD4ZOUrN4RqsxSPBAaW2tgNXwoNeBgx/ZIrDSqj1xKP2Dixri2AxAuTQvxLn249dAv6MRwBGWJDtqOo0606VdQ933lq7eoYy57wvLtHBQHqZnjboIUtBxQTLyHrGTc0UdUrWRTtU8geynX2ABRWYKrHsXixgqPcYiiJOyrMufQEWzXr4u6PQs5LiSVsM9b6n8Aq184LDJiybDhQXEYnO8VeCV8v8GaDOGV4HB9W/15Fpxd/ ca']
            node.normal['openssh']['revoked_keys'] = ['ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeNFbS05i75Na662aH5uzXvdWqWxLELs1kEy3L60EYJpZ9GzJ4ByR7Gk2EQE5Knvpm/ck3en6ef1nyJzniELrPwO1OwVqVfNGjiz+4cl9EjReuk+wKWhoHpM2clEpp52Kl0TSBKt+oDCsv0REc0uSyi7rWkQSuRqnZvoxx3M7UIWJhMpFYKM2Few8c90ckHG4SY1Qcj2E/zI5ueVDz/jRfogF10dgSC8J4H6OO9+4N42EASQDbWFx1CO5jqB+1dmf3/7KbvdZUsO9zF1D5Kphk+bLm4SnIQsOJE5cfnqSNIvP6UcW2gNxHD4inxGQvz5Gljk3yYZ7n6HwDHo7hukpP user']
          end.converge('openssh::default')
        end

        it 'writes the ca_keys' do
          template = chef_run.template(ca_keys_path)
          expect(template).to be
        end

        it 'writes the revoked_keys' do
          template = chef_run.template(revoked_keys_path)
          expect(template).to be
        end

        it 'writes ca public key to ca_keys file' do
          expect(chef_run).to render_file(ca_keys_path)
            .with_content { |content|
              expect(content).to include('ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJt7VN0YkI2jVnWUod8I/Qy9Am4lq0VOmFUTbzrMVTM8iut8E7heWu8G5QsDFLi3BNcU5wnwWO8rTWZZh1CJq6+zVn010rUYZhDxjlvFD4ZOUrN4RqsxSPBAaW2tgNXwoNeBgx/ZIrDSqj1xKP2Dixri2AxAuTQvxLn249dAv6MRwBGWJDtqOo0606VdQ933lq7eoYy57wvLtHBQHqZnjboIUtBxQTLyHrGTc0UdUrWRTtU8geynX2ABRWYKrHsXixgqPcYiiJOyrMufQEWzXr4u6PQs5LiSVsM9b6n8Aq184LDJiybDhQXEYnO8VeCV8v8GaDOGV4HB9W/15Fpxd/ ca')
            }
        end

        it 'writes user public key to revoked_keys file' do
          expect(chef_run).to render_file(revoked_keys_path)
            .with_content { |content|
              expect(content).to include('ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeNFbS05i75Na662aH5uzXvdWqWxLELs1kEy3L60EYJpZ9GzJ4ByR7Gk2EQE5Knvpm/ck3en6ef1nyJzniELrPwO1OwVqVfNGjiz+4cl9EjReuk+wKWhoHpM2clEpp52Kl0TSBKt+oDCsv0REc0uSyi7rWkQSuRqnZvoxx3M7UIWJhMpFYKM2Few8c90ckHG4SY1Qcj2E/zI5ueVDz/jRfogF10dgSC8J4H6OO9+4N42EASQDbWFx1CO5jqB+1dmf3/7KbvdZUsO9zF1D5Kphk+bLm4SnIQsOJE5cfnqSNIvP6UcW2gNxHD4inxGQvz5Gljk3yYZ7n6HwDHo7hukpP user')
            }
        end
      end
    end
  end
end
