const path = require('path');

module.exports = {
  entry: './src/main.ts',
  target: 'node',
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
    alias: {
      '@': path.resolve(__dirname, 'src'),
      'types': path.resolve(__dirname, 'types')
    }
  },
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
    library: {
      type: 'commonjs2'
    }
  },
  externals: {
    // Make the Flow JS export available as an external dependency
    '../flow_export': {
      commonjs: './flow_export.js',
      commonjs2: './flow_export.js',
      amd: './flow_export.js',
      root: 'FlowExport'
    }
  },
  optimization: {
    minimize: false, // We'll handle minification separately with terser
  },
  devtool: 'source-map',
  mode: 'production'
};