# TODO 
# add autopilot which will move towards the brightest point during the zoom process
# https://en.wikipedia.org/wiki/Luma_(video)

require "gosu"
require "complex"

module Modes 
  Julia      = 0b0001
  Mandelbrot = 0b0010
  Hsv        = 0b0100
  Rgb        = 0b1000
end

WIDTH                = 800
HEIGHT               = 600
WH_RATIO             = WIDTH.to_f / HEIGHT.to_f
MAX_ITERATIONS       = 200 
RGB_ITERATIONS_RATIO = 255.0 / MAX_ITERATIONS

Pixel = Struct.new(
        :x, 
        :y,
        :color)

class Mandelbrot < Gosu::Window

  def initialize(mode, zoom_factor)
    super WIDTH, HEIGHT
    self.caption = "mandelbrot test"
    @mode = mode
    # Both REAL_AXIS and IMAGINARY_AXIS must have same ratio 
    # view_radius is basically the starting point scale 
    @view_radius = 0.01
    @zoom_point = [-1.748, 0.0]
    @real_axis      = [@zoom_point[0] - @view_radius, @zoom_point[0] + @view_radius]
    @imaginary_axis = [@zoom_point[1] - (@view_radius/WH_RATIO), @zoom_point[1] + (@view_radius / WH_RATIO)] 

    @zoom_factor = zoom_factor 

    @x_step = (@real_axis[1] - @real_axis[0]).abs / WIDTH.to_f 
    @x_m = (@real_axis[0] + @real_axis[1]) / 2.0
    @x = (@real_axis[0]..@real_axis[1]).step(@x_step).to_a
    @y_step = (@imaginary_axis[1] - @imaginary_axis[0]).abs / HEIGHT.to_f 
    @y_m = (@imaginary_axis[0] + @imaginary_axis[1]) / 2.0
    @y = (@imaginary_axis[0]..@imaginary_axis[1]).step(@y_step).to_a
    @loaded_from_dump = false
    @dumps = nil 
    @current_dump_idx = 0
    @pixels = []
  end

  def transpose(x, y, cx, cy) 

    # Matrix A:
    # 
    # +---------------------+
    # | -2, 2 | 0, 2 | 2, 2 |
    # +-------+------+------+
    # | -2, 0 | 0, 0 | 2, 0 |
    # +-------+------+------+
    # | -2,-2 | 0,-2 | 2,-2 |
    # +-------+------+------+
    # 
    # Matrix B:
    # 
    # +---------------------+
    # | 0, 0  | 1, 0 | 2, 0 |
    # +-------+------+------+
    # | 0, 1  | 1, 1 | 2, 1 |
    # +-------+------+------+
    # | 0, 2  | 1, 2 | 2, 2 |
    # +-------+------+------+
    # 
    # The goal is to convert the MatrixB coordinate system to MatrixA
    # In MatrixA, x coordinate means the distance between the center (0,0)
    # In MatrixB, x coordinate means the distance between the left corner
    # So, in order to convert the x coordinate from B to A, we need to:
    #   1) Find the the center coordinate in MatrixB which is 1 ((matrix_width - 1) / 2)
    #   2) Substract current x coord from center coordinate, to find delta x
    #   3) Transpose the delta x to MatrixA world by multiplying with stepA
    # 
    # To convert the y coordinate do the following:
    #   1) Find the center coordinate in MatrixB, which is 1 ((matrix_height - 1) / 2)
    #   2) Substract (center_y - current_y) to find delta y
    #   3) Multiply delta y with stepA

    tx = (x - cx) * DIVISION_SCALE_X
    ty = (cy - y) * DIVISION_SCALE_Y

    return [tx, ty]
  end

  def compute_color(alpha, iteration)
    #return COLOR_PALETTE[iteration]
    color = alpha << 24
#    r = (RGB_ITERATIONS_RATIO * iteration).to_i << 16
#    g = (RGB_ITERATIONS_RATIO * iteration).to_i << 8 
#    b = (RGB_ITERATIONS_RATIO * iteration).to_i << 0 
    r = ((((iteration / MAX_ITERATIONS.to_f)**0.86) * 255)**1.5 % 255).floor << 16
    g = ((((iteration / MAX_ITERATIONS.to_f)**0.73) * 255)**1.5 % 255).floor << 8 
    b = ((((iteration / MAX_ITERATIONS.to_f)**0.68) * 255)**1.5 % 255).floor << 0 
    color |= r | g | b
    return color
  end

  ################ JUST FOR TEST ################
  def julia(x, y)
    #c0 = Complex(-0.8, 0.156)
    c0 = Complex(-0.4, 0.6)
    c  = Complex(x,y)

    MAX_ITERATIONS.times do |i|
      if(c.abs > 2) 
        # outside of the julia set
        if (@mode & Modes::Hsv) == Modes::Hsv
          return Gosu::Color.from_hsv((360.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i)
        else 
          color = compute_color(0xff, i)
          return Gosu::Color.argb(color)
        end
      else
        c = c**2 + c0
      end
    end
    return Gosu::Color.argb(0x00_000000)
  end
  ################ JUST FOR TEST ################

  def mandelbrot(x,y)
    zx = x 
    zy = y
    #c0 = Complex(x, y) 
    # we start from zero

    if (@mode & Modes::Hsv) == Modes::Hsv
      MAX_ITERATIONS.times do |i|
        if(zx**2 + zy**2 > 4)
          # outside of the mandelbrot set
            return Gosu::Color.from_hsv((360.0 / MAX_ITERATIONS) * i, 
                                         (1.0 / MAX_ITERATIONS) * i, 
                                         (1.0 / MAX_ITERATIONS) * i).to_i
        else
          temp = zx 
          zx = zx**2 - zy**2 + x
          zy = 2 * temp * zy + y 
        end
      end
    else
      MAX_ITERATIONS.times do |i|
        if(zx**2 + zy**2 > 4)
          # outside of the mandelbrot set
          color = compute_color(0xff, i)
          return Gosu::Color.argb(color).to_i
        else
          temp = zx 
          zx = zx**2 - zy**2 + x
          zy = 2 * temp * zy + y 
        end
      end

    end

    return Gosu::Color.argb(0x00_000000).to_i
  end

  def init 
    HEIGHT.times do |y|
      WIDTH.times do |x|
        @pixels << Pixel.new(x, y, Gosu::Color.argb(0x00_000000).to_i) 
      end
    end
  end

  def precompute()
    if (@mode & Modes::Mandelbrot) == Modes::Mandelbrot
      @pixels.each do |pixel|
        pixel.color = mandelbrot(@x[pixel.x], @y[pixel.y])
      end
    else
      @pixels.each do |pixel|
        pixel.color = julia(@x[pixel.x], @y[pixel.y])
      end
    end
  end

  def draw()
    @pixels.each do |pixel|
      Gosu.draw_rect(pixel.x, pixel.y, 1,1, Gosu::Color.argb(pixel.color)) 
    end
  end 

  def dump(iterations=1000)
    # dumps to file, it is used to speed up the rendering process200
    # basically it means that we don't need to compute the mandelbrot
    # we just load the pixel buffer and render it
    print "wanna dump? (y/n): "
    d = gets.chomp.downcase

    if d == "y"
      # oops ;)  
    else 
      print "wanna play it? (y/n): "
      d = gets.chomp.downcase
      load() if d == "y" 
      return
    end

    puts "dumping..."
    puts "total iterations: #{iterations}"
    c = 100.0 / iterations

    iterations.times do |i|
      puts "#{(i*c).floor}% is done."
      precompute()
      File.open("dumps/dump_#{i}.bin", "wb"){|io| io.write(Marshal.dump(@pixels)) }
      update()
    end

    puts "done!"
    print "wanna play it? (y/n): "
    d = gets.chomp.downcase

    if d != "y" 
      puts "bye.."
      exit 
    end

    load()
  end

  def load()
    # loads the file that was dumped 
    # used in conjunction with dump function
    @loaded_from_dump = true
    @dumps = Dir.children("dumps").map{|n| n[/\d+/].to_i}.sort.map{|n| "dump_#{n}.bin"}
  end

  def update()
    # we just don't update it 
    if @loaded_from_dump
      return if @current_dump_idx == @dumps.size
      # load all from files
      fname = @dumps[@current_dump_idx]
      @pixels = Marshal.load(File.binread(File.join("dumps", fname)))
      puts "playing frame #{fname}"
      @current_dump_idx+=1 if @current_dump_idx < @dumps.size
      return
    end

    @real_axis[0] += (@x_m - @real_axis[0]) * @zoom_factor
    @real_axis[1] -= (@real_axis[1] - @x_m) * @zoom_factor

    @imaginary_axis[0] += (@y_m - @imaginary_axis[0]) * @zoom_factor 
    @imaginary_axis[1] -= (@imaginary_axis[1] - @y_m) * @zoom_factor 

    @x_step = (@real_axis[1] - @real_axis[0]).abs / WIDTH.to_f 
    @y_step = (@imaginary_axis[1] - @imaginary_axis[0]).abs / HEIGHT.to_f 

    @x = (@real_axis[0]..@real_axis[1]).step(@x_step).to_a
    @y = (@imaginary_axis[0]..@imaginary_axis[1]).step(@y_step).to_a

    @x_m = (@real_axis[0] + @real_axis[1]) / 2.0
    @y_m = (@imaginary_axis[0] + @imaginary_axis[1]) / 2.0

    precompute()
  end

end

m = Mandelbrot.new(Modes::Mandelbrot | Modes::Rgb, 0.1)
m.init
#m.precompute()
m.dump(3000)
m.show

