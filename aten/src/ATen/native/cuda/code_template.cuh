  typedef long long int int64_t;
  static_assert(sizeof(int64_t) == 8, "expected size does not match");
  constexpr int num_threads = 64;
  constexpr int thread_work_size = 4; //TODO make template substitution once we decide where those vars live
  constexpr int block_work_size = thread_work_size * num_threads;

  template <typename T, int size>
  struct Array {
    T data[size];

    __device__ T operator[](int i) const {
      return data[i];
    }
    __device__ T& operator[](int i) {
      return data[i];
    }
    Array() = default;
    Array(const Array&) = default;
    Array& operator=(const Array&) = default;
  };

  template <typename T>
  struct DivMod {
    T div;
    T mod;

    __device__ DivMod(T _div, T _mod) {
      div = _div;
      mod = _mod;
    }
  };

  //<unsigned int>
  struct IntDivider {
    IntDivider() = default;

  __device__ inline unsigned int div(unsigned int n) const {
    unsigned int t = __umulhi(n, m1);
    return (t + n) >> shift;
  }

  __device__ inline unsigned int mod(unsigned int n) const {
    return n - div(n) * divisor;
  }

  __device__ inline DivMod<unsigned int> divmod(unsigned int n) const {
    unsigned int q = div(n);
    return DivMod<unsigned int>(q, n - q * divisor);
  }

  unsigned int divisor;  // d above.
  unsigned int m1;  // Magic number: m' above.
  unsigned int shift;  // Shift amounts.
};

  template<int NARGS>
  struct OffsetCalculator {
    OffsetCalculator() = default;
    __device__ __forceinline__ Array<${index_type}, NARGS> get(${index_type} linear_idx) const {
      Array<${index_type}, NARGS> offsets;
      #pragma unroll
      for (int arg = 0; arg < NARGS; ++arg) {
        offsets[arg] = 0;
      }

      #pragma unroll
      for (int dim = 0; dim < 25; ++dim) {
        if (dim == dims) {
          break;
        }

        auto divmod = sizes_[dim].divmod(linear_idx);
        linear_idx = divmod.div;

        #pragma unroll
        for (int arg = 0; arg < ${nInputs}; ++arg) {
          offsets[arg] += divmod.mod * strides_[dim][arg];
        }
      }
      return offsets;
    }

    int dims;
    IntDivider sizes_[25];
    // NOTE: this approach will not support nInputs == 0
    ${index_type} strides_[25][NARGS];
  };

  ${functor}

  // NOTE: assumes the op is binary (i.e. has three arguments out, a, and b)
  // TODO: setup grid-stride loop
  extern "C" __global__
  void ${name}_kernel(
      ${name}<${scalar_type}> functor,
      const int numel,
      Array<char*, ${nInputs}+1> data, //[${nInputs}+1],
      OffsetCalculator<${nInputs}> input_calculator,
      OffsetCalculator<1> output_calculator) {

    ${declare_load_arrays}
    ${declare_store_arrays}

    int idx = blockIdx.x;

    int remaining = numel - block_work_size * idx;
    auto thread_idx = threadIdx.x;

    #pragma unroll
    for (int j = 0; j < thread_work_size; j++){
      if (thread_idx >= remaining) {
        break;
      }
      int linear_idx = thread_idx + block_work_size * idx;
      auto input_offsets = input_calculator.get(linear_idx);
      // printf(
      //     "thread %d data %p %p %p offset %d %d\n",
      //     threadIdx.x,
      //     data[0], data[1], data[2],
      //     input_offsets[0], input_offsets[1]);
      ${load_inputs}
      thread_idx += num_threads;
    }

    #pragma unroll
    for (int j = 0; j < thread_work_size; j++) {
      out[j] = functor(${args});
    }

    thread_idx = threadIdx.x;
    for (int j = 0; j < thread_work_size; j++){
      if (thread_idx >= remaining) {
        break;
      }
      //TODO maybe think about unifying offset calculators and reuse
      //offsets computed in the load loop
      int linear_idx = thread_idx + block_work_size * idx;
      auto output_offsets = output_calculator.get(linear_idx);
      //TODO handle multi-return functors
      *(reinterpret_cast<${scalar_type}*>(data[0])+output_offsets[0]) = out[j];
      thread_idx += num_threads;
    }

    // NOTE: only the first thread operates on the first element for now
    //if (blockIdx.x == 0 && threadIdx.x == 0)
    {
      // ${scalar_type} a_value;
      // int a_offset = a.index_to_offset(0);

      // ${scalar_type} b_value;
      // int b_offset = b.index_to_offset(0);

      // int out_offset = out.index_to_offset(0);

      // // TODO: refactor the loading, see c10::fetch_and_cast
      // if (a.scalar_type_ == 0) {
      //   a_value = static_cast<${scalar_type}>(*(reinterpret_cast<float*>(a.data_ + a_offset)));
      // } else if (a.scalar_type_ == 1) {
      //   a_value = static_cast<${scalar_type}>(*(reinterpret_cast<double*>(a.data_ + a_offset)));
      // }

      // if (b.scalar_type_ == 0) {
      //   b_value = static_cast<${scalar_type}>(*(reinterpret_cast<float*>(b.data_ + b_offset)));
      // } else if (b.scalar_type_ == 1) {
      //   b_value = static_cast<${scalar_type}>(*(reinterpret_cast<double*>(b.data_ + b_offset)));
      // }

      // ${scalar_type} out_value = functor(a_value, b_value);

      // // TODO: refactor the storing, see c10::cast_and_store
      // if (out.scalar_type_ == 0) {
      //   *(reinterpret_cast<float*>(out.data_ + out_offset)) = static_cast<float>(out_value);
      // } else if (out.scalar_type_ == 1) {
      //   *(reinterpret_cast<double*>(out.data_ + out_offset)) = static_cast<double>(out_value);
      // }

      // printf("%f\n", out_value);
      }
  }

// instantiations here
