require File.dirname(__FILE__) + '/../../../../config/environment'
require 'test/unit'
require 'mocha'

$asset_packages_yml = YAML.load_file("#{RAILS_ROOT}/vendor/plugins/asset_packager/test/asset_packages.yml")
$asset_base_path = "#{RAILS_ROOT}/vendor/plugins/asset_packager/test/assets"

class AssetPackagerTest < Test::Unit::TestCase
  include Synthesis

  def setup
    Synthesis::AssetPackage.any_instance.stubs(:log)
    Synthesis::AssetPackage.build_all
  end

  def teardown
    Synthesis::AssetPackage.delete_all
  end

  def test_find_by_type
    js_asset_packages = Synthesis::AssetPackage.find_by_type("javascripts")
    assert_equal 2, js_asset_packages.length
    assert_equal "base", js_asset_packages[0].target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], js_asset_packages[0].sources
  end

  def test_find_by_target
    package = Synthesis::AssetPackage.find_by_target("javascripts", "base")
    assert_equal "base", package.target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], package.sources
  end

  def test_find_by_source
    package = Synthesis::AssetPackage.find_by_source("javascripts", "controls")
    assert_equal "base", package.target
    assert_equal ["prototype", "effects", "controls", "dragdrop"], package.sources
  end

  def test_delete_and_build
    Synthesis::AssetPackage.delete_all
    js_package_names = Dir.new("#{$asset_base_path}/javascripts").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.js/) }
    css_package_names = Dir.new("#{$asset_base_path}/stylesheets").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }
    css_subdir_package_names = Dir.new("#{$asset_base_path}/stylesheets/subdir").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }

    assert_equal 0, js_package_names.length
    assert_equal 0, css_package_names.length
    assert_equal 0, css_subdir_package_names.length

    Synthesis::AssetPackage.build_all
    js_package_names = Dir.new("#{$asset_base_path}/javascripts").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.js/) }.sort
    css_package_names = Dir.new("#{$asset_base_path}/stylesheets").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }.sort
    css_subdir_package_names = Dir.new("#{$asset_base_path}/stylesheets/subdir").entries.delete_if { |x| ! (x =~ /\A\w+_packaged.css/) }.sort

    assert_equal 2, js_package_names.length
    assert_equal 2, css_package_names.length
    assert_equal 1, css_subdir_package_names.length
    assert js_package_names[0].match(/\Abase_packaged.js\z/)
    assert js_package_names[1].match(/\Asecondary_packaged.js\z/)
    assert css_package_names[0].match(/\Abase_packaged.css\z/)
    assert css_package_names[1].match(/\Asecondary_packaged.css\z/)
    assert css_subdir_package_names[0].match(/\Astyles_packaged.css\z/)
  end

  def test_js_names_from_sources
    package_names = Synthesis::AssetPackage.targets_from_sources("javascripts", ["prototype", "effects", "noexist1", "controls", "foo", "noexist2"])
    assert_equal 4, package_names.length
    assert package_names[0].match(/\Abase_packaged\z/)
    assert_equal package_names[1], "noexist1"
    assert package_names[2].match(/\Asecondary_packaged\z/)
    assert_equal package_names[3], "noexist2"
  end

  def test_css_names_from_sources
    package_names = Synthesis::AssetPackage.targets_from_sources("stylesheets", ["header", "screen", "noexist1", "foo", "noexist2"])
    assert_equal 4, package_names.length
    assert package_names[0].match(/\Abase_packaged\z/)
    assert_equal package_names[1], "noexist1"
    assert package_names[2].match(/\Asecondary_packaged\z/)
    assert_equal package_names[3], "noexist2"
  end

  def test_should_return_merge_environments_when_set
    Synthesis::AssetPackage.merge_environments = ["staging", "production"]
    assert_equal ["staging", "production"], Synthesis::AssetPackage.merge_environments
  end

  def test_should_only_return_production_merge_environment_when_not_set
    assert_equal ["production"], Synthesis::AssetPackage.merge_environments
  end

  def test_fix_relative_urls
    css_fragments = [
      {
        :content => '.ui-state-hover { border: 1px solid #448dae; background: #79c9ec url(images/ui-bg_glass_75_79c9ec_1x400.png) 50% 50% repeat-x; font-weight: normal; color: #026890; outline: none; }',
        :path => 'ui.css',
        :fixed_url => 'url(./images/ui-bg_glass_75_79c9ec_1x400.png)'
      },
      {
        :content => '.ui-state-hover { border: 1px solid #448dae; background: #79c9ec url(images/ui-bg_glass_75_79c9ec_1x400.png) 50% 50% repeat-x; font-weight: normal; color: #026890; outline: none; }',
        :path => 'vendor/jquery/ui.css',
        :fixed_url => 'url(vendor/jquery/images/ui-bg_glass_75_79c9ec_1x400.png)'
      },
      {
        :content => <<-CSS,
        .model_step {
            background: transparent url(../../images/icons_standard_20px.gif) no-repeat 0px -6452px;
            border-bottom: 1px dotted #888783;
            color: #69A733;
            font-size: 1.2em;
            font-weight: bold;
            padding: .5em .5em .5em 28px;
        }'
        CSS
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url(company/pages/../../images/icons_standard_20px.gif)'
      },
      {
        :content => '#newSpeciesBtn { float: right; background: #65a52d url(../images/icons_16_green.gif) no-repeat 6px -286px; color: #fff; padding: .1em 10px .2em 25px; text-decoration: none; white-space: nowrap; font-size: 1.1em; margin: 0pt 5px 5px 0pt; }',
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url(company/pages/../images/icons_16_green.gif)'
      },
      {
        :content => '#newSpeciesBtn { float: right; background: #65a52d url( ./images/icons_16_green.gif ) no-repeat 6px -286px; color: #fff; padding: .1em 10px .2em 25px; text-decoration: none; white-space: nowrap; font-size: 1.1em; margin: 0pt 5px 5px 0pt; }',
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url( company/pages/./images/icons_16_green.gif )'
      },
      {
        :content => '#newSpeciesBtn { float: right; background: #65a52d url(/images/icons_16_green.gif) no-repeat 6px -286px; color: #fff; padding: .1em 10px .2em 25px; text-decoration: none; white-space: nowrap; font-size: 1.1em; margin: 0pt 5px 5px 0pt; }',
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url(/images/icons_16_green.gif)'
      },
      {
        :content => '#newSpeciesBtn { float: right; background: #65a52d url(http://localhost/images/icons_16_green.gif) no-repeat 6px -286px; color: #fff; padding: .1em 10px .2em 25px; text-decoration: none; white-space: nowrap; font-size: 1.1em; margin: 0pt 5px 5px 0pt; }',
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url(http://localhost/images/icons_16_green.gif)'
      },
      {
        :content => '#newSpeciesBtn { float: right; background: #65a52d url(https://localhost/images/icons_16_green.gif ) no-repeat 6px -286px; color: #fff; padding: .1em 10px .2em 25px; text-decoration: none; white-space: nowrap; font-size: 1.1em; margin: 0pt 5px 5px 0pt; }',
        :path => 'company/pages/simulation.css',
        :fixed_url => 'url(https://localhost/images/icons_16_green.gif )'
      }
    ]

    # CSS package should fix relative urls
    css_package = Synthesis::AssetPackage.find_by_type('stylesheets').first
    css_fragments.each do |f|
      fixed_content = css_package.send(:fix_relative_urls, f[:content], f[:path])
      assert_equal f[:fixed_url], fixed_content[/url\([^)]+\)/]
    end

    # JS package should not touch urls
    js_package = Synthesis::AssetPackage.find_by_type('javascripts').first
    css_fragments.each do |f|
      fixed_content = js_package.send(:fix_relative_urls, f[:content], f[:path])
      assert_equal f[:content], fixed_content
    end
  end

  def test_fix_relative_urls_with_merged_file
    secondary_package_file = Synthesis::AssetPackage.find_by_target('stylesheets', 'secondary').current_file
    subdir_package_file = Synthesis::AssetPackage.find_by_target('stylesheets', 'subdir/styles').current_file

    secondary_package = File.read("#{$asset_base_path}/stylesheets/#{secondary_package_file}.css")
    assert_not_nil secondary_package.index('url(./images/ui-bg_glass_75_79c9ec_1x400.png)')
    assert_not_nil secondary_package.index('url(subdir/../images/icons_16_green.gif)')
    assert_not_nil secondary_package.index('url( subdir/./images/icons_16_red.gif )')
    subdir_package = File.read("#{$asset_base_path}/stylesheets/#{subdir_package_file}.css")
    assert_not_nil subdir_package.index('url(./../images/icons_16_green.gif)')
    assert_not_nil subdir_package.index('url( ././images/icons_16_red.gif )')
  end
end
