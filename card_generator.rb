#!/usr/bin/env ruby
require 'rubygems'
require 'rmagick'
require 'yaml'
$file = YAML.load_file(ARGV[0])

$sections = ["title", "cost", "class", "collection", "text", "artist", "stats"]

$frame_brightness  = 1.0
$frame_saturation  = 1.0
$frame_hue         = 1.0
$frame_x           = 630
$frame_y           = 880
$illustration_x    = 525
$illustration_y    = 385
$textbox_x         = 530
$textbox_y         = 275
$text_line         = 32
$illustration_file = ARGV[1] == nil ? File.expand_path(File.dirname(__FILE__)) + "/assets/default_illustration.png" : ARGV[1]

$parameters = {}
$sections.each { | section | $parameters[section] = {} }

$parameters["text"]       = { "size" => 18, "font" => "MPlantin",     "padding" => 10, "color" => "black", "margin_top" => 53,  "align" => "left"  }

$parameters["title"]      = { "size" => 24, "font" => "Beleren-Bold", "padding" => 10, "color" => "black", "margin_top" => 55,  "align" => "left"  }

$parameters["cost"]       = { "size" => 24, "font" => "MPlantin",     "padding" => 10, "color" => "black", "margin_top" => 58,  "align" => "right" }

$parameters["class"]      = { "size" => 24, "font" => "Beleren-Bold", "padding" => 10, "color" => "black", "margin_top" => 502, "align" => "left"  }

$parameters["collection"] = { "size" => 24, "font" => "Beleren-Bold", "padding" => 10, "color" => "black", "margin_top" => 502, "align" => "right" }

$parameters["artist"]     = { "size" => 24, "font" => "MPlantin",     "padding" => 10, "color" => "black", "margin_top" => 810, "align" => "left"  }

$parameters["stats"]      = { "size" => 24, "font" => "MPlantin",     "padding" => 10, "color" => "black", "margin_top" => 810, "align" => "right" }

$sections.each { | section | $parameters[section]["value"] = "" }
$file.keys.each { | key |
    case key
    when "frame_hue"
        $frame_hue = $file[key]
    else
        $parameters[key]["value"] = $file[key]
    end
}

module RMagickTextUtil
    def render_cropped_text(caption_text, width_constraint, height_constraint, &block)
        image = render_text(caption_text, width_constraint, &block)
        if height_constraint < image.rows
            percent = height_constraint.to_f / image.rows.to_f
            end_index = (caption_text.size * percent).to_i  # takes a leap into cropping
            image = render_text(caption_text[0..end_index] + "…", width_constraint, &block)
            while height_constraint < image.rows && end_index > 0 # reduce in big chunks until within range
                end_index -= 80
                image = render_text(caption_text[0..end_index] + "…", width_constraint, &block)
            end
            while height_constraint > image.rows                  # lengthen in smaller steps until exceed
                end_index += 10
                image = render_text(caption_text[0..end_index] + "…", width_constraint, &block)
            end
            while height_constraint < image.rows && end_index > 0 # reduce in baby steps until fit
                end_index -= 1
                image = render_text(caption_text[0..end_index] + "…", width_constraint, &block)
            end
        end
        image
    end

    def render_text(caption_text, width_constraint, &block)
        Magick::Image.read("caption:#{caption_text.to_s}") {
            # this wraps the text to fixed width
            self.size = width_constraint
            # other optional settings
            block.call(self) if block_given?
        }.first
    end
end
include RMagickTextUtil

include Magick

# Image objects
img          = Image.new($frame_x,$frame_y) { self.background_color = "none" }
frame        = Magick::Image::read(File.expand_path(File.dirname(__FILE__)) + "/assets/frame.png")[0]
illustration = Magick::Image::read($illustration_file)[0]
textbox      = Image.new($textbox_x,$textbox_y) { self.background_color = "#ffffff" }

# Image manipulations
frame.resize_to_fit! $frame_x,$frame_y
illustration.resize_to_fill! $illustration_x, $illustration_y

frame = frame.modulate $frame_brightness, $frame_saturation, $frame_hue

$sections.each do | section |

    width = $textbox_x - ($parameters[section]["padding"] * 2)
    height = section == "text" ? $textbox_y - ($parameters[section]["padding"] * 0.5) : $text_line

    text = render_cropped_text($parameters[section]["value"], width, height) do |img|
        img.fill = $parameters[section]["color"] # this won't work until RMagick v1.15.3
        img.font = File.expand_path(File.dirname(__FILE__)) + '/assets/fonts/' + $parameters[section]["font"] + '.ttf'
        img.pointsize = $parameters[section]["size"]
        img.background_color = "none"

        case $parameters[section]["align"]
        when "left"
            img.gravity = Magick::NorthWestGravity
        when "right"
            img.gravity = Magick::NorthEastGravity
        else
            img.gravity = Magick::CenterGravity
        end
    end

    case section
    when "text"
        textbox.composite! text, $parameters[section]["padding"], $parameters[section]["padding"] - 3, OverCompositeOp
    else
        frame.composite! text, 50 + $parameters[section]["padding"], $parameters[section]["margin_top"], OverCompositeOp
    end
end

# Combine images
img.composite! textbox, 48, 546, OverCompositeOp
img.composite! illustration, 52, 102, OverCompositeOp
img.composite! frame, 0, 0, OverCompositeOp

img.gravity = CenterGravity

img.write("./" + $parameters["title"]["value"] + ".png")
