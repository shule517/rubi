require_relative '../rubi.rb'

describe Rubi::Parser do
  describe '#parse' do
    subject { Rubi::Parser.new.parse(tokens) }
    let(:tokens) { Rubi::Tokenizer.new.split_tokens(str) }

    context '()*1' do
      let(:str) { "(+ 1 2)" }
      it { is_expected.to eq [[:+, 1, 2]] }
    end

    context '()*2' do
      let(:str) { "(+ (+ 1 2) 3)" }
      it { is_expected.to eq [[:+, [:+, 1, 2], 3]] }
    end

    context '二重かっこ' do
      let(:str) { "(defun double (x) (* x 2))" }
      it { is_expected.to eq [[:defun, :double, [:x], [:*, :x, 2]]] }
    end

    context '複数行' do
      let(:str) do
        <<~LISP
          (define x 3)
          (+ x 4)
        LISP
      end
      it { is_expected.to eq [[:define, :x, 3], [:+, :x, 4]] }
    end

    context '文字列の場合' do
      let(:str) do
        <<~LISP
          "あ"
        LISP
      end
      it { is_expected.to eq [:"\"あ\""] }
    end
  end

  describe '#expand_syntactic_sugar' do
    subject { pp ast: ast; parser.expand_syntactic_sugar(ast) }

    let(:parser) { Rubi::Parser.new }
    let(:ast) { parser.parse(tokens) }
    let(:tokens) { Rubi::Tokenizer.new.split_tokens(str) }

    context 'quoteの糖衣構文' do
      context "'の場合" do
        context 'シンボルの場合' do
          let(:str) { "'a" }
          before { expect(ast).to eq [:"'", :a] }
          it { is_expected.to eq [[:quote, :a]] }
        end

        context '記号の場合' do
          let(:str) { "(funcall '+ 1 2)" }
          before { expect(ast).to eq [[:funcall, :"'", :+, 1, 2]] }
          it { is_expected.to eq [[:funcall, [:quote, :+], 1, 2]] }
        end

        context 'リストの場合' do
          let(:str) { "'(1 2 a)" }
          before { expect(ast).to eq [:"'", [1, 2, :a]] }
          it { is_expected.to eq [[:quote, [1, 2, :a]]] }
        end
      end

      context "`の場合" do
        context 'シンボルの場合' do
          let(:str) { "`a" }
          before { expect(ast).to eq [:`, :a] }
          it { is_expected.to eq [[:quote, :a]] }
        end

        context '記号の場合' do
          let(:str) { "(funcall `+ 1 2)" }
          before { expect(ast).to eq [[:funcall, :`, :+, 1, 2]] }
          it { is_expected.to eq [[:funcall, [:quote, :+], 1, 2]] }
        end

        context 'リストの場合' do
          let(:str) { "`(1 2 a)" }
          before { expect(ast).to eq [:"`", [1, 2, :a]] }
          it { is_expected.to eq [[:quote, [1, 2, :a]]] }
        end
      end

      context "`,の変数展開①" do
        let(:str) { "`(1 ,(+ 1 2))" }
        before { expect(ast).to eq [:`, [1, :",", [:+, 1, 2]]] }
        it { is_expected.to eq [[:quote, [1, [:unquote, [:+, 1, 2]]]]] }
      end

      context "`,の変数展開②" do
        let(:str) { "`(a (,b c))" }
        before { expect(ast).to eq [:`, [:a, [:",", :b, :c]]] }
        it { is_expected.to eq [[:quote, [:a, [[:unquote, :b], :c]]]] }
      end

      context ",@の変数展開" do
        let(:str) { "`(a ,@b c)" }
        before { expect(ast).to eq [:`, [:a, :",@", :b, :c]] }
        it { is_expected.to eq [[:quote, [:a, [:"unquote-splicing", :b], :c]]] }
      end

      context "'(a . b)の展開" do
        let(:str) { "'(a . b)" }
        before { expect(ast).to eq [:"'", [:a, :".", :b]] }
        it { is_expected.to eq [[:quote, [:a, :".", :b]]] }
      end

      context "'(a . 2)の展開" do
        let(:str) { "'(a . 2)" }
        before { expect(ast).to eq [:"'", [:a, :".", 2]] }
        it { is_expected.to eq [[:quote, [:a, :".", 2]]] }
      end

      context "`(a . 2)の展開" do
        let(:str) { "`(a . 2)" }
        before { expect(ast).to eq [:"`", [:a, :".", 2]] }
        it { is_expected.to eq [[:quote, [:a, :".", 2]]] }
      end

      context "(car '(a . 1))の展開" do
        let(:str) { "(car '(a . 1))" }
        before { expect(ast).to eq [[:car, :"'", [:a, :".", 1]]] }
        it { is_expected.to eq [[:car, [:quote, [:a, :".", 1]]]] }
      end

      context "`(1 . 2)の展開" do
        let(:str) { "`(1 . 2)" }
        before { expect(ast).to eq [:"`", [1, :".", 2]] }
        it { is_expected.to eq [[:quote, [1, :".", 2]]] }
      end

      context "(1 . 2)の展開" do
        let(:str) { "(1 . 2)" }
        before { expect(ast).to eq [[1, :".", 2]] }
        it { is_expected.to eq [[1, :".", 2]] }
      end

      context "'((a . 1) (b . 2) (c . 3)) => (quote ((a . 1) (b . 2) (c . 3)))" do
        let(:str) { "'((a . 1) (b . 2) (c . 3))" }
        before { expect(ast).to eq [:"'", [[:a, :".", 1], [:b, :".", 2], [:c, :".", 3]]] }
        it { is_expected.to eq [[:quote, [[:a, :".", 1], [:b, :".", 2], [:c, :".", 3]]]] }
      end

      context "(car '((a . 1) (b . 2) (c . 3))) => (car (quote ((a . 1) (b . 2) (c . 3))))" do
        let(:str) { "(car '((a . 1) (b . 2) (c . 3)))" }
        before { expect(ast).to eq [[:car, :"'", [[:a, :".", 1], [:b, :".", 2], [:c, :".", 3]]]] }
        it { is_expected.to eq [[:car, [:quote, [[:a, :".", 1], [:b, :".", 2], [:c, :".", 3]]]]] }
      end

      context "'((a b) (c d e))" do
        let(:str) { "'((a b) (c d e))" }
        before { expect(ast).to eq [:"'", [[:a, :b], [:c, :d, :e]]] }
        it { is_expected.to eq [[:quote, [[:a, :b], [:c, :d, :e]]]] }
      end

      context "#'の場合" do
        let(:str) { "#'double" }
        before { expect(ast).to eq [:"#'", :double] }
        it { is_expected.to eq [[:function, :double]] }
      end
    end
  end
end
