require 'rake'

desc 'installs the dot files into the user home directory'
task :install do
  if File.exists?(File.join(ENV['HOME'], '.oh-my-zsh'))
    puts 'oh-my-zsh exists, ignored.'
  else
    puts 'Installing oh-my-zsh ...'
    system 'curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh'
  end

  if File.exists?(File.join(ENV['HOME'], '.vimrc')) && File.exists?(File.join(ENV['HOME'], '.vim', 'janus'))
    puts 'Janus exists, ignored.'
  else
    puts 'Installing Janus ...'
    system 'curl -Lo- http://bit.ly/janus-bootstrap | bash'
  end

  Dir['*'].each do |file|
    next if %w[zsh Rakefile README.md].include? file

    target_file = File.join(ENV['HOME'], ".#{file}")

    if File.exist?(target_file)
      if File.identical?(target_file, file)
        puts "#{target_file} is identical, ignored."
        next
      else
        FileUtils.mv target_file, "#{target_file}.backup.#{Time.now.to_i}"
        puts "#{target_file} is backed up."
      end
    end

    system %Q{ln -s "$PWD/#{file}" "$HOME/.#{file}"}
    puts "#{file} is linked."
  end
end

task :default => :install