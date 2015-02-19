/**************************************--**************************************\
|*                                                                            *|
|*                                   PAXOS                                    *|
|*                                                                            *|
|*                                                                            *|
\**************************************--**************************************/

class Interface // singleton
{
	var machine_ID: int; // A unique pseudorandom ID
	var groups:     map<int, Group>; // groups we participate in

	// INSIDE
	method Promise(dest_ID: int, group_ID: int, slot_ID: int,
		value: int) {}

	method Prepare(dest_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {}

	method Accept(dest_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {}

	method Learn(dest_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {}

	// OUTSIDE
	method Recieve_Propose(source_ID: int, group_ID: int, slot_ID: int,
		value: int) {
		// Are we a member of this group & have a proposer for this slot?
		if (group_ID in this.groups) {
			var local := this.groups[group_ID].local_proposers;
			if (slot_ID in local) {
				local[slot_ID].Propose(0, value);
			} // TODO: else create new slot??
		}
	}

	method Recieve_Promise(source_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {
		// Are we a member of this group & have a proposer for this slot?
		if (group_ID in this.groups) {
			var local := this.groups[group_ID].local_proposers;
			if (slot_ID in local) {
				local[slot_ID].Promise(round, value);
			}
		}
	}

	method Recieve_Prepare(source_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {
		// Are we a member of this group & have an acceptor for this slot?
		if (group_ID in this.groups) {
			var local := this.groups[group_ID].local_acceptors;
			if (slot_ID in local) {
				local[slot_ID].Prepare(source_ID, round, value);
			}
		}
	}

	method Recieve_Accept(source_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {
		// Are we a member of this group & have an acceptor for this slot?
		if (group_ID in this.groups) {
			var local := this.groups[group_ID].local_acceptors;
			if (slot_ID in local) {
				local[slot_ID].Accept(round, value);
			}
		}
	}

	method Recieve_Learn(source_ID: int, group_ID: int, slot_ID: int,
		round: int, value: int) {
		// Are we a member of this group & have a learner for this slot?
		if (group_ID in this.groups) {
			var local := this.groups[group_ID].local_learners;
			if (slot_ID in local) {
				local[slot_ID].Learn(round, value);
			}
		}
	}


	/* Store
	 * This method is to be overridden by the client application in the effort
	 * to provide safe storage of information to a non-volatile device.
	 */
	method Store(value: int) {}

	method EventLearn(round: int, value: int) {}
}

// TODO: reduce arguments machine_ID, group_ID, slot_ID, round, value to a
// single object (less copying)


/* StateMachine
 * keeps data about how to reach a replica. IP/ports/protocols/keys/etc.
 */
class StateMachine {}

class Group
{
	var interface: Interface; // singelton
	var ID:        int; // this group's group_ID

	var proposers: array<StateMachine>;
	var acceptors: array<StateMachine>;
	var learners:  array<StateMachine>;
	// TODO rename one of these sets
	var local_proposers: map<int, Proposer>; // key is slot_ID
	var local_acceptors: map<int, Acceptor>;
	var local_learners:  map<int, Learner>;

	constructor Init()
	{
		this.proposers := new array<StateMachine>;
		this.acceptors := new array<StateMachine>;
		this.learners  := new array<StateMachine>;
	}

	method Prepare(slot_ID: int, round: int, value: int)
	{
		var i := 0;
		var n := this.acceptors.Length;
		while (i < n)
			invariant 0 <= i <= n;
		{
			this.interface.Prepare(acceptors[i], this.ID, slot_ID, round, value);
			i := i + 1;
		}
	}

	method Accept(slot_ID: int, round: int, value: int)
	{
		var i := 0;
		var n := this.acceptors.Length;
		while (i < n)
			invariant 0 <= i <= n;
		{
			this.interface.Accept(acceptors[i], this.ID, slot_ID, round, value);
			i := i + 1;
		}
	}

	method Learn(slot_ID: int, round: int, value: int)
	{
		var i := 0;
		var n := this.learners.Length;
		while (i < n)
			invariant 0 <= i <= n;
		{
			this.interface.Learn(learners[i], this.ID, slot_ID, round, value);
			i := i + 1;
		}
	}
}

class Proposer
{
	var interface: Interface; // singelton
	var group:     Group; // list participating members
	var slot_ID:   int; // unique slot identifier

	var round:     int; // current round
	var largest:   int; // largerst encountered round from acceptors
	var value:     int; // own value or value of acceptor with largest round
	var promised:  map<StateMachine, bool>; // bitmap of answered promises
	var count:     int; // amount of responses received

	constructor Init(id: int, group: Group, value: int)
	{
		this.slot_ID  := id;
		this.group    := group;
		this.round    := 0;
		this.largest  := 0;
		this.value    := value;
		this.promised := new map<StateMachine, bool>;
		this.count    := 0;
		group.Prepare(round, value, pro); // broadcast to all acceptors in group
	}

	/* can be called by a malicious proposer?
	 * The Proposer receives a response from an Acceptor where the current round
	 * is the highest encountered.
	 */
	method Promise(source_ID: int, acceptedround: int, acceptedval: int)
		requires acceptedround <= this.round;
		ensures  acceptedround != null && this.largest < acceptedround
			==> this.value == acceptedval;
	{
		// not first response from acceptor?
		if (this.promised[sender]) { return; }
		this.promised[sender] := true;
		this.count := this.count + 1; // +1 promise

		// were there any prior proposals?
		if (acceptedround != null && this.largest < acceptedround) {
			this.value   := acceptedval;
			this.largest := acceptedround;
		}

		// TODO: don't call Accept before all Prepares are sent!
		// got required majority of promises?
		if (count > group.acceptors.Length/2) {
			// TODO: store state
			this.interface.Accept(round, value);
		}
	}
}

class Acceptor
{
	var interface:     Interface; // singelton
	var group:         Group; // list participating members
	var slot_ID:       int; // unique slot identifier

	var promise :      int;
	var acceptedround: int;
	var acceptedval:   int;
	var learners:      map<int, StateMachine>;

	method Prepare(source: int, round: int, value: int)
	{
		// is the round newer than our promise?
		if (round > this.promise) {
			this.promise := round;
			this.interface.Promise(source, this.group, this.slot_ID,
				this.acceptedround, this.acceptedval);
		}
	}

	method Accept(round: int, value: int)
		requires 2 < 3;
	{
		// is the round at least as new as the promise
		if (round >= this.promise && round != this.acceptedround) {
			this.promise       := round;
			this.acceptedround := round;
			this.acceptedval   := value;
			this.group.Learn(round, value);
		}
	}
}

class Learner
{
	var interface: Interface; // singelton

	method Learn(round: int, value: int)
	{
		interface.EventLearn(round, value);
	}
}