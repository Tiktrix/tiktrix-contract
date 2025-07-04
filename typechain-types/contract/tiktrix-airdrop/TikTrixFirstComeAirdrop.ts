/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  EventFragment,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedLogDescription,
  TypedListener,
  TypedContractMethod,
} from "../../common";

export interface TikTrixFirstComeAirdropInterface extends Interface {
  getFunction(
    nameOrSignature:
      | "DEFAULT_ADMIN_ROLE"
      | "airdropAmount"
      | "claim"
      | "contractURI"
      | "deployer"
      | "emergencyWithdraw"
      | "getAirdropAmount"
      | "getMaxClaim"
      | "getRemainingClaim"
      | "getRoleAdmin"
      | "getRoleMember"
      | "getRoleMemberCount"
      | "grantRole"
      | "hasClaimed"
      | "hasRole"
      | "hasRoleWithSwitch"
      | "maxClaim"
      | "owner"
      | "renounceRole"
      | "revokeRole"
      | "setContractURI"
      | "totalClaimed"
  ): FunctionFragment;

  getEvent(
    nameOrSignatureOrTopic:
      | "AirdropClaimed"
      | "ContractURIUpdated"
      | "EmergencyWithdrawn"
      | "RoleAdminChanged"
      | "RoleGranted"
      | "RoleRevoked"
  ): EventFragment;

  encodeFunctionData(
    functionFragment: "DEFAULT_ADMIN_ROLE",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "airdropAmount",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "claim", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "contractURI",
    values?: undefined
  ): string;
  encodeFunctionData(functionFragment: "deployer", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "emergencyWithdraw",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getAirdropAmount",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getMaxClaim",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getRemainingClaim",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleAdmin",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleMember",
    values: [BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "getRoleMemberCount",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "grantRole",
    values: [BytesLike, AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "hasClaimed",
    values: [AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "hasRole",
    values: [BytesLike, AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "hasRoleWithSwitch",
    values: [BytesLike, AddressLike]
  ): string;
  encodeFunctionData(functionFragment: "maxClaim", values?: undefined): string;
  encodeFunctionData(functionFragment: "owner", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "renounceRole",
    values: [BytesLike, AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "revokeRole",
    values: [BytesLike, AddressLike]
  ): string;
  encodeFunctionData(
    functionFragment: "setContractURI",
    values: [string]
  ): string;
  encodeFunctionData(
    functionFragment: "totalClaimed",
    values?: undefined
  ): string;

  decodeFunctionResult(
    functionFragment: "DEFAULT_ADMIN_ROLE",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "airdropAmount",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "claim", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "contractURI",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "deployer", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "emergencyWithdraw",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getAirdropAmount",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getMaxClaim",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRemainingClaim",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRoleAdmin",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRoleMember",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getRoleMemberCount",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "grantRole", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "hasClaimed", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "hasRole", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "hasRoleWithSwitch",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "maxClaim", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "owner", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "renounceRole",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "revokeRole", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "setContractURI",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "totalClaimed",
    data: BytesLike
  ): Result;
}

export namespace AirdropClaimedEvent {
  export type InputTuple = [claimer: AddressLike, amount: BigNumberish];
  export type OutputTuple = [claimer: string, amount: bigint];
  export interface OutputObject {
    claimer: string;
    amount: bigint;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace ContractURIUpdatedEvent {
  export type InputTuple = [prevURI: string, newURI: string];
  export type OutputTuple = [prevURI: string, newURI: string];
  export interface OutputObject {
    prevURI: string;
    newURI: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace EmergencyWithdrawnEvent {
  export type InputTuple = [amount: BigNumberish, to: AddressLike];
  export type OutputTuple = [amount: bigint, to: string];
  export interface OutputObject {
    amount: bigint;
    to: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace RoleAdminChangedEvent {
  export type InputTuple = [
    role: BytesLike,
    previousAdminRole: BytesLike,
    newAdminRole: BytesLike
  ];
  export type OutputTuple = [
    role: string,
    previousAdminRole: string,
    newAdminRole: string
  ];
  export interface OutputObject {
    role: string;
    previousAdminRole: string;
    newAdminRole: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace RoleGrantedEvent {
  export type InputTuple = [
    role: BytesLike,
    account: AddressLike,
    sender: AddressLike
  ];
  export type OutputTuple = [role: string, account: string, sender: string];
  export interface OutputObject {
    role: string;
    account: string;
    sender: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export namespace RoleRevokedEvent {
  export type InputTuple = [
    role: BytesLike,
    account: AddressLike,
    sender: AddressLike
  ];
  export type OutputTuple = [role: string, account: string, sender: string];
  export interface OutputObject {
    role: string;
    account: string;
    sender: string;
  }
  export type Event = TypedContractEvent<InputTuple, OutputTuple, OutputObject>;
  export type Filter = TypedDeferredTopicFilter<Event>;
  export type Log = TypedEventLog<Event>;
  export type LogDescription = TypedLogDescription<Event>;
}

export interface TikTrixFirstComeAirdrop extends BaseContract {
  connect(runner?: ContractRunner | null): TikTrixFirstComeAirdrop;
  waitForDeployment(): Promise<this>;

  interface: TikTrixFirstComeAirdropInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  DEFAULT_ADMIN_ROLE: TypedContractMethod<[], [string], "view">;

  airdropAmount: TypedContractMethod<[], [bigint], "view">;

  claim: TypedContractMethod<[], [void], "nonpayable">;

  contractURI: TypedContractMethod<[], [string], "view">;

  deployer: TypedContractMethod<[], [string], "view">;

  emergencyWithdraw: TypedContractMethod<[], [void], "nonpayable">;

  getAirdropAmount: TypedContractMethod<[], [bigint], "view">;

  getMaxClaim: TypedContractMethod<[], [bigint], "view">;

  getRemainingClaim: TypedContractMethod<[], [bigint], "view">;

  getRoleAdmin: TypedContractMethod<[role: BytesLike], [string], "view">;

  getRoleMember: TypedContractMethod<
    [role: BytesLike, index: BigNumberish],
    [string],
    "view"
  >;

  getRoleMemberCount: TypedContractMethod<[role: BytesLike], [bigint], "view">;

  grantRole: TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;

  hasClaimed: TypedContractMethod<[arg0: AddressLike], [boolean], "view">;

  hasRole: TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [boolean],
    "view"
  >;

  hasRoleWithSwitch: TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [boolean],
    "view"
  >;

  maxClaim: TypedContractMethod<[], [bigint], "view">;

  owner: TypedContractMethod<[], [string], "view">;

  renounceRole: TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;

  revokeRole: TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;

  setContractURI: TypedContractMethod<[_uri: string], [void], "nonpayable">;

  totalClaimed: TypedContractMethod<[], [bigint], "view">;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "DEFAULT_ADMIN_ROLE"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "airdropAmount"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "claim"
  ): TypedContractMethod<[], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "contractURI"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "deployer"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "emergencyWithdraw"
  ): TypedContractMethod<[], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "getAirdropAmount"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "getMaxClaim"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "getRemainingClaim"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "getRoleAdmin"
  ): TypedContractMethod<[role: BytesLike], [string], "view">;
  getFunction(
    nameOrSignature: "getRoleMember"
  ): TypedContractMethod<
    [role: BytesLike, index: BigNumberish],
    [string],
    "view"
  >;
  getFunction(
    nameOrSignature: "getRoleMemberCount"
  ): TypedContractMethod<[role: BytesLike], [bigint], "view">;
  getFunction(
    nameOrSignature: "grantRole"
  ): TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "hasClaimed"
  ): TypedContractMethod<[arg0: AddressLike], [boolean], "view">;
  getFunction(
    nameOrSignature: "hasRole"
  ): TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [boolean],
    "view"
  >;
  getFunction(
    nameOrSignature: "hasRoleWithSwitch"
  ): TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [boolean],
    "view"
  >;
  getFunction(
    nameOrSignature: "maxClaim"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "owner"
  ): TypedContractMethod<[], [string], "view">;
  getFunction(
    nameOrSignature: "renounceRole"
  ): TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "revokeRole"
  ): TypedContractMethod<
    [role: BytesLike, account: AddressLike],
    [void],
    "nonpayable"
  >;
  getFunction(
    nameOrSignature: "setContractURI"
  ): TypedContractMethod<[_uri: string], [void], "nonpayable">;
  getFunction(
    nameOrSignature: "totalClaimed"
  ): TypedContractMethod<[], [bigint], "view">;

  getEvent(
    key: "AirdropClaimed"
  ): TypedContractEvent<
    AirdropClaimedEvent.InputTuple,
    AirdropClaimedEvent.OutputTuple,
    AirdropClaimedEvent.OutputObject
  >;
  getEvent(
    key: "ContractURIUpdated"
  ): TypedContractEvent<
    ContractURIUpdatedEvent.InputTuple,
    ContractURIUpdatedEvent.OutputTuple,
    ContractURIUpdatedEvent.OutputObject
  >;
  getEvent(
    key: "EmergencyWithdrawn"
  ): TypedContractEvent<
    EmergencyWithdrawnEvent.InputTuple,
    EmergencyWithdrawnEvent.OutputTuple,
    EmergencyWithdrawnEvent.OutputObject
  >;
  getEvent(
    key: "RoleAdminChanged"
  ): TypedContractEvent<
    RoleAdminChangedEvent.InputTuple,
    RoleAdminChangedEvent.OutputTuple,
    RoleAdminChangedEvent.OutputObject
  >;
  getEvent(
    key: "RoleGranted"
  ): TypedContractEvent<
    RoleGrantedEvent.InputTuple,
    RoleGrantedEvent.OutputTuple,
    RoleGrantedEvent.OutputObject
  >;
  getEvent(
    key: "RoleRevoked"
  ): TypedContractEvent<
    RoleRevokedEvent.InputTuple,
    RoleRevokedEvent.OutputTuple,
    RoleRevokedEvent.OutputObject
  >;

  filters: {
    "AirdropClaimed(address,uint256)": TypedContractEvent<
      AirdropClaimedEvent.InputTuple,
      AirdropClaimedEvent.OutputTuple,
      AirdropClaimedEvent.OutputObject
    >;
    AirdropClaimed: TypedContractEvent<
      AirdropClaimedEvent.InputTuple,
      AirdropClaimedEvent.OutputTuple,
      AirdropClaimedEvent.OutputObject
    >;

    "ContractURIUpdated(string,string)": TypedContractEvent<
      ContractURIUpdatedEvent.InputTuple,
      ContractURIUpdatedEvent.OutputTuple,
      ContractURIUpdatedEvent.OutputObject
    >;
    ContractURIUpdated: TypedContractEvent<
      ContractURIUpdatedEvent.InputTuple,
      ContractURIUpdatedEvent.OutputTuple,
      ContractURIUpdatedEvent.OutputObject
    >;

    "EmergencyWithdrawn(uint256,address)": TypedContractEvent<
      EmergencyWithdrawnEvent.InputTuple,
      EmergencyWithdrawnEvent.OutputTuple,
      EmergencyWithdrawnEvent.OutputObject
    >;
    EmergencyWithdrawn: TypedContractEvent<
      EmergencyWithdrawnEvent.InputTuple,
      EmergencyWithdrawnEvent.OutputTuple,
      EmergencyWithdrawnEvent.OutputObject
    >;

    "RoleAdminChanged(bytes32,bytes32,bytes32)": TypedContractEvent<
      RoleAdminChangedEvent.InputTuple,
      RoleAdminChangedEvent.OutputTuple,
      RoleAdminChangedEvent.OutputObject
    >;
    RoleAdminChanged: TypedContractEvent<
      RoleAdminChangedEvent.InputTuple,
      RoleAdminChangedEvent.OutputTuple,
      RoleAdminChangedEvent.OutputObject
    >;

    "RoleGranted(bytes32,address,address)": TypedContractEvent<
      RoleGrantedEvent.InputTuple,
      RoleGrantedEvent.OutputTuple,
      RoleGrantedEvent.OutputObject
    >;
    RoleGranted: TypedContractEvent<
      RoleGrantedEvent.InputTuple,
      RoleGrantedEvent.OutputTuple,
      RoleGrantedEvent.OutputObject
    >;

    "RoleRevoked(bytes32,address,address)": TypedContractEvent<
      RoleRevokedEvent.InputTuple,
      RoleRevokedEvent.OutputTuple,
      RoleRevokedEvent.OutputObject
    >;
    RoleRevoked: TypedContractEvent<
      RoleRevokedEvent.InputTuple,
      RoleRevokedEvent.OutputTuple,
      RoleRevokedEvent.OutputObject
    >;
  };
}
