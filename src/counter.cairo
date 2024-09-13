#[starknet::interface]
pub trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
}

#[starknet::contract]
pub mod counter_contract {
    use starknet::event::EventEmitter;
    use workshop::counter::ICounter;
    use core::starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        value: u32,
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState>{

        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            
            let ks = self.kill_switch.read();
            let ks_dispatcher = IKillSwitchDispatcher{ contract_address: ks };

            assert!(ks_dispatcher.is_active() == false, "Kill Switch is active");
            
            let value = self.get_counter();

            self.counter.write(value + 1);
            self.emit(CounterIncreased { value: self.get_counter() })
        }
    }
}