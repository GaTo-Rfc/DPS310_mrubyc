# 高精度気圧センサDPS310用Rubyクラス
# 作成者: GaTo
# 参考資料: https://files.seeedstudio.com/products/101020812/res/DPS310-datasheet.pdf

# coding: utf-8

# プログラム内で使用する定数
# アドレス
I2C_ADDR = 0x77   # センサのI2Cポートのアドレス
COEF_ADRS = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21]    # 校正係数が格納されているメモリのアドレス
TEMP_ADRS = [0x03, 0x04, 0x05]    # 気温の測定値が格納されているメモリのアドレス
PRES_ADRS = [0x00, 0x01, 0x02]    # 気圧の測定値が格納されているメモリのアドレス

# バイト数
MEAS_DATA_SIZE = 24             # 測定値のバイト数
ONE_DIGIT_COEF_SIZE = 12        # c0, c1のバイト数
TWO_DIGIT_COEF_SIZE_ONE = 20    # c00, c10のバイト数
TWO_DIGIT_COEF_SIZE_TWO = 16    # c01, c11, c20, c21, c30のバイト数

# クラス本体
class DPS310
  # attr宣言
  attr_reader :temp, :pres

  # 初期化
  def initialize(i2c)
    @i2c = i2c  # I2Cの変数

    read_coef
    meas_init
  end

  # メモリ書き込み関数
  def write(adrs, data)
    @i2c.writeto(I2C_ADDR, adrs, data)
  end

  # メモリ読み取り関数
  def read(adrs)
    @i2c.read(I2C_ADDR, 1, adrs)
  end

  # 2の補数を考慮した値に変換する
  def cons_two_comp(data, lng)
    (data > 2 ** (lng - 1) - 1) ? data - 2 ** lng : data
  end

  # 校正係数を取得（データシートP37を参照）
  def read_coef
    @cfs = []   # 校正係数のデータを格納する配列
    # 各メモリからデータを取得
    COEF_ADRS.each do |adrs|
      @cfs << read(adrs).ord
    end

    # 校正係数を取得するためにビット演算
    @c0 = (@cfs[0] * 2 ** 4) + ((@cfs[1] / 2 ** 4) & 0x0f)
    @c0 = cons_two_comp(@c0, ONE_DIGIT_COEF_SIZE).to_f

    @c1 = ((@cfs[1] & 0x0f) * 2 ** 8) + @cfs[2]
    @c1 = cons_two_comp(@c1, ONE_DIGIT_COEF_SIZE).to_f

    @c00 = (@cfs[3] * 2 ** 12) + (@cfs[4] * 2 ** 4) + ((@cfs[5] / 2 ** 4) & 0x0f)
    @c00 = cons_two_comp(@c00, TWO_DIGIT_COEF_SIZE_ONE).to_f

    @c10 = ((@cfs[5] & 0x0f) * 2 ** 16) + (@cfs[6] * 2 ** 8) + @cfs[7]
    @c10 = cons_two_comp(@c10, TWO_DIGIT_COEF_SIZE_ONE).to_f

    @c01 = @cfs[9] + @cfs[8] * 2 ** 8
    @c01 = cons_two_comp(@c01, TWO_DIGIT_COEF_SIZE_TWO).to_f

    @c11 = @cfs[11] + @cfs[10] * 2 ** 8
    @c11 = cons_two_comp(@c11, TWO_DIGIT_COEF_SIZE_TWO).to_f

    @c20 = @cfs[13] + @cfs[12] * 2 ** 8
    @c20 = cons_two_comp(@c20, TWO_DIGIT_COEF_SIZE_TWO).to_f

    @c21 = @cfs[15] + @cfs[14] * 2 ** 8
    @c21 = cons_two_comp(@c21, TWO_DIGIT_COEF_SIZE_TWO).to_f

    @c30 = @cfs[17] + @cfs[16] * 2 ** 8
    @c30 = cons_two_comp(@c30, TWO_DIGIT_COEF_SIZE_TWO).to_f
  end

  # 計測用に設定
  def meas_init
    # メモリに設定を書き込み
    write(0x06, 0x01)   # 気圧測定の設定
    write(0x07, 0x80)   # 気温測定の設定
    write(0x09, 0x00)   # その他の設定
  end

  # 気温測定
  def temp_meas
    write(0x08, 0x02)   # 動作モードの設定
    @tmps = []    # 測定値を格納する関数

    # 気温測定値を読み取り
    TEMP_ADRS.each do |adrs|
      @tmps << read(adrs).ord
    end

    @tmp = @tmps[0] * 2 ** 16 + @tmps[1] * 2 ** 8 + @tmps[2]  # 数値変換
    @tmp = cons_two_comp(@tmp, MEAS_DATA_SIZE)

    # 校正係数を考慮して気温を計算
    @tsc = @tmp.to_f / 524288
    @temp = @c0 * 0.5 + @c1 * @tsc
  end

  # 気圧測定
  def pres_meas
    write(0x08, 0x01)   # 動作モードの設定
    @prss = []    # 測定値を格納する関数

    # 気圧測定値を読み取り
    PRES_ADRS.each do |adrs|
      @prss << read(adrs).ord
    end

    @prs = @prss[0] * 2 ** 16 + @prss[1] * 2 ** 8 + @prss[2]  # 数値変換
    @prs = cons_two_comp(@prs, MEAS_DATA_SIZE)

    # 校正係数を考慮して気圧を計算
    @psc = @prs.to_f / 1572864
    @pres = @c00 + @psc * (@c10 + @psc * (@c20 + @psc * @c30)) + @tsc * @c01 + @tsc * @psc * (@c11 + @psc * @c21)
  end

  # デバッグ用関数（ターミナルに各数値を表示）
  def debug
    puts "---------------"
    puts "C0= #{@c0}"
    puts "C1= #{@c1}"
    puts "C00= #{@c00}"
    puts "C10= #{@c10}"
    puts "C01= #{@c01}"
    puts "C11= #{@c11}"
    puts "C20= #{@c20}"
    puts "C21= #{@c21}"
    puts "C30= #{@c30}"
    puts "---------------"
    puts "TMP= #{@tmp}"
    puts "PRS= #{@prs}"
    puts "TSC= #{@tsc}"
    puts "PSC= #{@psc}"
    puts "---------------"
  end
end
