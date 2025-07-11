module xmn::xmn {
    use std::ascii::string;
    use sui::coin;
    use sui::url;
    use treasury::treasury;
    use sui_extensions::upgrade_service;

    /// The One-Time Witness struct for the XMN coin.
    public struct XMN has drop {}

    // === Constants ===

    const DESCRIPTION: vector<u8> = b"<placeholder>";
    const ICON_URL: vector<u8> = b"<placeholder>";

    #[allow(lint(share_owned))]
    /// Initializes
    /// - A shared Treasury<XMN> object
    /// - A shared UpgradeService<XMN> object
    fun init(witness: XMN, ctx: &mut TxContext) {
        let (upgrade_service, witness) = upgrade_service::new(
            witness,
            ctx.sender() /* admin */,
            ctx
        );

        let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
            witness,
            6,               // decimals
            b"XMN",         // symbol
            b"XMN",         // name
            DESCRIPTION,
            option::some(url::new_unsafe(string(ICON_URL))),
            true,            // allow global pause
            ctx
        );

        let treasury = treasury::new(
            treasury_cap, 
            deny_cap,
            ctx.sender(), // owner
            ctx.sender(), // master minter
            ctx.sender(), // blocklister
            ctx.sender(), // pauser
            ctx.sender(), // metadata updater
            ctx
        );
            
        transfer::public_share_object(metadata);
        transfer::public_share_object(treasury);
        transfer::public_share_object(upgrade_service);
    }

    #[test_only]
    public(package) fun init_for_testing(ctx: &mut TxContext) {
        init(XMN {}, ctx)
    }
}
