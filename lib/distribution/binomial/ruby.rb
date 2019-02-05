module Distribution
  module Binomial
    module Ruby_
      class << self
        # Returns a `Proc`object that yields a random integer `k` <= `n`
        # which is binomially distributed with mean np and variance np(1-p)
        # This method uses a variant of Luc Devroye's 
        # "Second Waiting Time Method" on page 522 of his text 
        # "Non-Uniform Random Variate Generation." for np < 1e-3
        # For all other values it finds the sum of n IID bernoulli variates
        #
        # @param n [Integer] the total number of trials
        # @param prob [Float] probabilty of success in a single independant trial
        # @param seed [Integer, nil] Value to initialize the generator with.
        #   The seed is always taken modulo 100000007. If omitted the value is
        #   remainder of `Random.new_seed` mod 100000007
        #
        # @return [Proc] a proc that generates a binomially distributed integer
        #   `k` <= `n` when called
        def rng(n, prob, seed = nil)
          seed = Random.new_seed if seed.nil?
          seed = seed.modulo 100_000_007
          prng = Random.new(seed)
          np = n * prob
          k = 0
          
          if np < 1e-3
            # An efficient technique that works for small values of `n` * `prob`
            # http://stackoverflow.com/q/23561551/
            log_q = Math.log(1 - prob)
            sum = 0
            return -> {
              while true
                sum += Math.log(rand) / (n - k)
                next k if sum < log_q
                k += 1
              end
            }
          else
            # First principles algorithm
            # Slow and a candidate for replacement
            bernoulli_generator = lambda do |rng, p|
              if rng.rand > p
                0
              else
                1
              end
            end
            
            # A binomial variate is the sum of n IID bernoulli trials
            -> {
              Array.new(n) { 
                bernoulli_generator.call(prng, prob)
              }.reduce(:+)
            }
          end
        end
        
        # Returns the probability mass function for a binomial variate
        # having `k` successes out of `n` trials, with each success having
        # probability `prob`.
        #
        # @param k [Integer, Bignum] number of successful trials
        # @param n [Integer, Bignum] total number of trials
        # @param prob [Float] probabilty of success in a single independant trial
        #
        # @return [Float] the probability mass for Binom(k, n, prob)        
        def pdf(k, n, prob)
          fail 'k > n' if k > n
          Math.binomial_coefficient(n, k) * (prob**k) * (1 - prob)**(n - k)
        end

        alias_method :exact_pdf, :pdf

        # TODO: Use exact_regularized_beta for
        # small values and regularized_beta for bigger ones.
        def cdf(k, n, prob)
          # (0..x.floor).inject(0) {|ac,i| ac+pdf(i,n,pr)}
          Math.regularized_beta(1 - prob, n - k, k + 1)
        end

        # Returns the exact CDF value by summing up all preceding values
        #
        # @param k [Integer, Bignum] number of successful trials
        # @param n [Integer, Bignum] total number of trials
        # @param prob [Float] probabilty of success in a single independant trial
        def exact_cdf(k, n, prob)
          out = (0..k).inject(0) { |ac, i| ac + pdf(i, n, prob) }
          out = 1 if out > 1.0
          out
        end
        
        # Returns the inverse-CDF or the quantile given the probability `prob`,
        # the total number of trials `n` and the number of successes `k`
        # Note: This is a candidate for future updates
        #
        # @paran qn [Float] the cumulative function value to be inverted
        # @param n [Integer, Bignum] total number of trials
        # @param prob [Float] probabilty of success in a single independant trial
        #
        # @return [Integer, Bignum] the integer quantile `k` given cumulative value
        #
        # @raise RangeError if qn is from outside of the closed interval [0, 1]
        def quantile(qn, n, pr)
          fail RangeError, 'cdf value(qn) must be from [0, 1]. '\
            "Cannot find quantile for qn=#{qn}" if qn > 1 || qn < 0
          ac = 0
          (0..n).each do |i|
            ac += pdf(i, n, pr)
            return i if qn <= ac
          end
        end
        
        alias_method :p_value, :quantile
      end
    end
  end
end
