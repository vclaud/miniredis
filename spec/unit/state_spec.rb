require 'spec_helper'
require 'miniredis/state'

describe Miniredis::State, :unit do
	let(:clock) {FakeClock.new()}
	let(:state) {described_class.new(clock)}

	shared_examples 'passive expiry' do |set_cmd, get_cmd|
		it 'expires a key passively' do
			key = "abc"

			set_cmd.(state, key)
			state.expire(key, "1")

			clock.sleep 0.9
			get_cmd.(state, key)
			expect(state.exists(key)).to eq(1)

			clock.sleep 0.1
			get_cmd.(state, key)
			expect(state.exists(key)).to eq(0)
		end
	end

	describe '#set' do
		it 'sets a value' do
			expect(state.set("abc", "123")).to eq(:ok)
			expect(state.get("abc")).to eq("123")
		end

		it 'does not overwrite an existing value with NX' do
			expect(state.set("abc", "123", "NX")).to eq(:ok)
			expect(state.set("abc", "456", "NX")).to eq(nil)
			expect(state.get("abc")).to eq("123")
		end

		it 'does not set a new value with XX' do
			expect(state.set("abc", "123", "XX")).to eq(nil)
			state.set("abc", "123")
			expect(state.set("abc", "456", "XX")).to eq(:ok)
			expect(state.get("abc")).to eq("456")
		end

		it 'returns error for wrong number of arguments' do
			expect(state.set("abc")).to \
				eq(Miniredis::Error.incorrect_args('set'))
		end
	end

	describe '#hset' do
		it 'sets a value' do
			expect(state.hset("myhash", "abc", "123")).to eq(:ok)
			expect(state.hset("other", "def", "456")).to eq(:ok)
			expect(state.hget("myhash", "abc")).to eq("123")
		end
	end

	describe "#hmget" do
		it 'returns multiple values at once' do
			expect(state.hset("myhash", "abc", "123")).to eq(:ok)
			expect(state.hset("myhash", 'def', "456")).to eq(:ok)
			expect(state.hmget("myhash", "abc", "def")).to eq(["123", "456"])
		end

		it 'returns error when not hash value' do
			state.set("myhash", "bogus")
			expect(state.hmget("myhash", "key")).to \
				eq(Miniredis::Error.type_error)
		end

		it 'returns nils when empty' do
			expect(state.hmget("myhash", "key")).to \
				eq([nil])
		end

		include_examples 'passive expiry',
			-> s, k {s.hset(k, "abc", "123")},
			-> s, k {s.hmget(k, "abc")}
	end

	describe '#hget' do
		include_examples 'passive expiry',
			-> s, k {s.hset(k, "abc", "123")},
			-> s, k {s.hget(k, "abc")}
	end

	describe '#hincrby' do
		it 'increments a counter stored in a hash' do
			state.hset("myhash", "abc", "123")
			expect(state.hincrby("myhash", "abc", "2")).to eq(125)
		end

		include_examples 'passive expiry',
			-> s, k {s.hset(k, "abc", "123")},
			-> s, k {s.hincrby(k, "abc", "1")}
	end

	describe '#get' do
		include_examples 'passive expiry',
			-> s, k {s.set(k, "123")},
			-> s, k {s.get(k)}
	end

	describe '#exists' do
		it 'returns the number of keys existing' do
			expect(state.exists("abc")).to eq(0)
			state.set("abc", "123")
			expect(state.exists("abc")).to eq(1)
		end
	end
end