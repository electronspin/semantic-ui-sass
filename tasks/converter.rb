# Based on convert script from vwall/compass-twitter-bootstrap gem.
# https://github.com/vwall/compass-twitter-bootstrap/blob/#{@branch}/build/convert.rb

require 'open-uri'
require 'json'
require 'fileutils'
require "pry"
require "dotenv"

require 'pathname'

Dotenv.load

class Converter

  GIT_DATA = 'https://api.github.com/repos'
  GIT_RAW  = 'https://raw.githubusercontent.com'
  TOKEN    = ENV['TOKEN']


  def initialize(branch)
    @repo               = 'Semantic-Org/Semantic-UI'
    @repo_url           = "https://github.com/#@repo"
    @branch             = branch || 'master'
    @git_data_trees     = "#{GIT_DATA}/#{@repo}/git/trees"
    @git_raw_src        = "#{GIT_RAW}/#{@repo}/#{@branch}/dist"
    @branch_sha         = get_tree_sha
  end

  def process
    # process_stylesheets_assets

    # process_images_and_fonts_assets
    # store_version

    checkout_repository
    choose_version(@branch)
    process_stylesheets_assets
    process_javascript_assets
    store_version
  end

  def paths
    @gem_paths ||= Paths.new
  end

  def checkout_repository
    if Dir.exist?(paths.tmp_semantic_ui)
      system %Q{cd '#{paths.tmp_semantic_ui}' && git fetch --quiet}
    else
      system %Q{git clone --quiet git@github.com:Semantic-Org/Semantic-UI.git '#{paths.tmp_semantic_ui}'}
    end
  end

  def choose_version(version)
    system %Q{cd '#{paths.tmp_semantic_ui}' && git checkout --quiet #{version}}
  end

  def process_stylesheets_assets
          # content = ""
    Dir[File.join(paths.tmp_semantic_ui_definitions, '*')].each do |path|
      # all = ""

      Dir[File.join(path, "*.less")].each do |file|

        filename = File.basename(file).gsub(".less", '.css')

        Dir[File.join(paths.tmp_semantic_ui_components, "*.css")].each do |src|
          name = File.basename(src)

         if name == filename
           file = open(src).read
           file = convert(file)
           save_file(name, file, File.basename(path))

           # all << "@import '#{name.gsub(".css", "")}';\n"
         end #filename
        end
      end
      # save_file("all", all, File.basename(path)) if all != ''
      # content << "@import 'semantic-ui/#{File.basename(path)}/all';\n";

    end
     # File.open("app/assets/stylesheets/semantic-ui.scss", "w+") { |file| file.write(content) }
  end


  def process_javascript_assets
    # js = ""
    Dir[File.join(paths.tmp_semantic_ui_definitions, '**/*.js')].each do |src|
       name = File.basename(src).gsub(".js", '')
       # js << "//= require #{name}\n"
       FileUtils.cp(src, paths.javascripts)
     end
     # File.open("app/assets/javascripts/semantic-ui.js", "w+") { |file| file.write(js) }
  end


private

  # Get the sha of less branch
  def get_tree_sha
    sha = nil
    trees = get_json("#{@git_data_trees}/#{@branch}")
    trees['tree'].find{|t| t['path'] == 'dist'}['sha']
  end


  def convert(file)
    file = replace_fonts_url(file)
    file = replace_image_urls(file)
    file = replace_image_paths(file)

    file
  end


  def save_file(name, content, path, type='stylesheets')

    name = name.gsub(/\.css/, '')
    file = "#{paths.stylesheets}/#{path}/_#{name}.scss"
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) unless File.directory?(file)
    File.open(file, 'w+') { |f| f.write(content) }
    # puts "Saved #{name} at #{path}\n"
  end



  def get_json(url)
    url += "?access_token=#{TOKEN}" unless TOKEN.nil?
    data = open_git_file(url)
    data = JSON.parse data
  end

  def open_git_file(file)
    open(file).read
  end

  def store_version
    path = 'lib/semantic/ui/sass/version.rb'
    content = File.read(path).sub(/SEMANTIC_UI_SHA\s*=\s*['"][\w]+['"]/, "SEMANTIC_UI_SHA = '#@branch_sha'")
    File.open(path, 'w') { |f| f.write(content) }
  end

  def replace_fonts_url(less)
    less.gsub(/url\(\"\.\.\/themes\/default\/assets\/fonts\/?(.*?)\"\)/) {|s| "font-url(\"semantic-ui/#{$1}\")" }
  end

  def replace_image_urls(less)
    less.gsub(/url\("?(.*?).png"?\)/) {|s| "image-url(\"#{$1}.png\")" }
  end

  def replace_image_paths(less)
    less.gsub('../themes/default/assets/images/', 'semantic-ui/')
  end

end

class Paths
   attr_reader :root
   attr_reader :tmp
   attr_reader :tmp_semantic_ui
   attr_reader :tmp_semantic_ui_src
   attr_reader :tmp_semantic_ui_definitions
   attr_reader :tmp_semantic_ui_dist
   attr_reader :tmp_semantic_ui_components

   attr_reader :fonts
   attr_reader :images
   attr_reader :javascripts
   attr_reader :stylesheets


   def initialize
     @root = File.expand_path('..', __dir__)

     @tmp = File.join(@root, 'tmp')
     @tmp_semantic_ui = File.join(@tmp, 'semantic-ui')
     @tmp_semantic_ui_src = File.join(@tmp_semantic_ui, 'src')
     @tmp_semantic_ui_definitions = File.join(@tmp_semantic_ui_src, 'definitions')

     @tmp_semantic_ui_dist = File.join(@tmp_semantic_ui, 'dist')
     @tmp_semantic_ui_components = File.join(@tmp_semantic_ui_dist, 'components')

     @app = File.join(@root, 'source')
     @fonts = File.join(@app, 'assets', 'fonts', 'semantic-ui')
     @images = File.join(@app, 'assets', 'images', 'semantic-ui')
     @javascripts = File.join(@app, 'assets', 'javascripts', 'semantic-ui')
     @stylesheets = File.join(@app, 'assets', 'stylesheets', 'semantic-ui')
   end
 end
