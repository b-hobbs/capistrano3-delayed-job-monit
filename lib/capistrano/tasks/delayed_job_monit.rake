namespace :load do
  task :defaults do
    set :delayed_job_monit_conf_dir, '/etc/monit/conf.d'
    set :delayed_job_monit_conf_file, -> { "delayed_job.conf" }
    set :delayed_job_monit_use_sudo, true
    set :monit_bin, '/usr/bin/monit'
    set :delayed_job_monit_default_hooks, true
    set :delayed_job_monit_templates_path, 'config/deploy/templates'
    set :delayed_job_monit_group, nil
  end
end

namespace :delayed_job do
  namespace :monit do
    desc 'Unmonitor a specific application'
    task :unmonitor do
      on roles(fetch(:delayed_job_roles)) do
        (0..3).each do |idx|
          run_command "#{fetch(:monit_bin)} unmonitor #{monit_service_name(idx)}"
        end
      end
    end

    desc 'Monitor a specific application'
    task :monitor do
      on roles(fetch(:delayed_job_roles)) do
        (0..3).each do |idx|
          run_command "#{fetch(:monit_bin)} monitor #{monit_service_name(idx)}"
        end
      end
    end


    desc 'Default task - conditionally restart'
    task :deploy do
      on roles(fetch(:delayed_job_roles)) do |role|
        within release_path do
          create_monit_service role
          monit_reload
        end
      end
    end

    def monit_reload
      run_command "#{fetch(:monit_bin)} reload"
    end

    def monit_service_name index
      "#{fetch(:application)}_#{fetch(:stage)}_delayed_job_#{index}"
    end

    def create_monit_service role
      filename = 'delayed_job_monit'
      tmp_location = "tmp/monit.conf"

      template = delayed_job_template(filename, role)
      upload!(StringIO.new(ERB.new(template).result(binding)), tmp_location)

      # run_command "mv #{fetch(:tmp_dir)}/monit.conf #{fetch(:delayed_job_monit_conf_dir)}/#{fetch(:delayed_job_monit_conf_file)}"
    end

    def delayed_job_template(name, role)
      local_template_directory = fetch(:delayed_job_monit_templates_path)

      search_paths = [
        "#{name}-#{role.hostname}-#{fetch(:stage)}.erb",
        "#{name}-#{role.hostname}.erb",
        "#{name}-#{fetch(:stage)}.erb",
        "#{name}.erb"
      ].map { |filename| File.join(local_template_directory, filename) }

      global_search_path = File.expand_path(
        File.join(*%w[.. .. .. generators capistrano delayed_job_monit templates], "#{name}.conf.erb"),
        __FILE__
      )

      search_paths << global_search_path

      template_path = search_paths.detect { |path| File.file?(path) }
      File.read(template_path)
    end

    def run_command(command)
      send(use_sudo? ? :sudo : :execute, command)
    end

    def use_sudo?
      fetch(:delayed_job_monit_use_sudo)
    end

    after 'deploy:published', 'delayed_job:monit:deploy' if Rake::Task.task_defined?('deploy:published')
    after 'delayed_job:default', 'delayed_job:monit:monitor' if Rake::Task.task_defined?('delayed_job:default')
    before 'delayed_job:stop', 'delayed_job:monit:unmonitor' if Rake::Task.task_defined?('delayed_job:stop')
  end





end